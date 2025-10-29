import stripe
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
from tv_backend.email_client import send_email
from tv_backend.logger import get_logger, log_request, log_api_call, log_user_action, log_error
from django.utils import timezone
from rest_framework import status

# views.py
from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser, FormParser
from accounts.models import User
from .models import ExpertAdvisor, ExpertUser
from .serializers import ExpertAdvisorSerializer, ExpertUserSerializer
from .filters import ExpertAdvisorFilter
from django.db.models import Count
from rest_framework.permissions import IsAuthenticated, BasePermission, SAFE_METHODS
import requests
from accounts.supabase_client import supabase



class IsProgrammerOrReadOnly(BasePermission):
    """
    Custom permission to only allow users with role 'programmer' to create,
    update, or delete if they are also the creator of the object.
    Read-only access is allowed for any authenticated user.
    """
    def has_object_permission(self, request, view, obj):
        # Allow read-only methods for any authenticated user
        if request.method in SAFE_METHODS:
            return bool(request.user and request.user.is_authenticated)
        # For write methods, user must be a programmer and the creator
        return (
            request.user and
            request.user.is_authenticated and
            getattr(request.user, 'role', None) == 'programmer' and
            hasattr(obj, 'created_by') and getattr(obj, 'created_by', None) == request.user
        )

class ExpertAdvisorPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 50

class ExpertAdvisorViewSet(ModelViewSet):
    """
    A viewset that provides CRUD operations and query capabilities for Expert Advisors.

    Endpoints (under `/api/experts/`):
    - GET `/api/experts/` — List all expert advisors (supports pagination, search, and ordering).
    - POST `/api/experts/` — Create a new expert advisor (restricted to authorized users, typically programmers).
    - GET `/api/experts/{id}/` — Retrieve a specific expert advisor by ID.
    - PUT `/api/experts/{id}/` — Update an existing expert advisor (full update).
    - PATCH `/api/experts/{id}/` — Partially update an existing expert advisor.
    - DELETE `/api/experts/{id}/` — Delete an expert advisor.

    Filtering, searching, and ordering can be applied via query parameters such as:
    - `?search=keyword` — search across name, description, or author.
    - `?ordering=created_at` or `?ordering=-download_count` — sort by specific fields.
    - `?page=2&page_size=10` — control pagination.
    """
    serializer_class = ExpertAdvisorSerializer
    filterset_class = ExpertAdvisorFilter
    pagination_class = ExpertAdvisorPagination
    ordering_fields = ['created_at', 'download_count']
    ordering = ['download_count']
    search_fields = ['name', 'description', 'author']
    permission_classes = [IsProgrammerOrReadOnly]
    
    def get_queryset(self):
        user = self.request.user
        log_request(self.request, "ExpertAdvisorViewSet.get_queryset")
        
        queryset = ExpertAdvisor.objects.annotate(
            download_count=Count('downloads')
        )
        if self.request.query_params.get('owned') == 'true' and user.is_authenticated:
            queryset = queryset.filter(created_by=user)
            log_user_action(user, "viewed_owned_experts", f"Filtered {queryset.count()} experts")
        
        return queryset

    def perform_destroy(self, instance):
        logger = get_logger()
        user = self.request.user
        
        log_user_action(user, "deleted_expert_advisor", f"Deleted EA: {instance.name} (ID: {instance.id})")
        
        # Clean up Stripe resources when deleting an Expert Advisor
        if instance.stripe_price_id:
            try:
                stripe.api_key = settings.STRIPE_SECRET_KEY
                
                # Get the price to find the product
                price = stripe.Price.retrieve(instance.stripe_price_id)
                product_id = price.product
                
                # Archive the price (Stripe doesn't allow deletion of prices)
                stripe.Price.modify(instance.stripe_price_id, active=False)
                
                # Archive the product (Stripe doesn't allow deletion of products)
                stripe.Product.modify(product_id, active=False)
                
                logger.info(f"Successfully cleaned up Stripe resources for expert {instance.id}")
                
            except Exception as e:
                logger.error(f"Failed to cleanup Stripe resources for expert {instance.id}: {e}")
                print(f"Failed to cleanup Stripe resources for expert {instance.id}: {e}")
        
        # Delete the instance
        instance.delete()

from rest_framework import status
from rest_framework.response import Response
from django.utils import timezone

class ExpertUserViewSet(ModelViewSet):
    serializer_class = ExpertUserSerializer
    permission_classes = [IsAuthenticated]
    queryset = ExpertUser.objects.all()

    def get_queryset(self):
        user = self.request.user
        if self.request.query_params.get('managed') == 'true' and user.role == 'programmer':
            return ExpertUser.objects.filter(expert__created_by=user)
        return ExpertUser.objects.filter(user=user)

    def perform_create(self, serializer):
        expert = serializer.validated_data.get('expert')
        existing = ExpertUser.objects.filter(user=self.request.user, expert=expert).exists()
        if existing:
            raise serializer.ValidationError("You are already subscribed to this Expert Advisor.")
        serializer.save(user=self.request.user)

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        # Custom logic: handle push via ?push=true
        if request.query_params.get("push") == "true":
            # Generate signed download link and send email
            expert_file_path = instance.expert.file  # This should be the path stored in the 'file' field
            download_url = None
            
            # Construct the full path including user ID folder
            if expert_file_path:
                # If the path doesn't already include the user ID, add it
                if not expert_file_path.startswith(f"{instance.expert.created_by.id}/"):
                    expert_file_path = f"{instance.expert.created_by.id}/{expert_file_path}"
                
                try:
                    download_url = supabase.storage.from_("ea-uploads").create_signed_url(expert_file_path, 3600).get("signedURL")
                except Exception as e:
                    error_msg = f"Failed to generate download URL for {expert_file_path}: {e}"
                    log_error(error_msg)
                    return Response({'error': error_msg}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            else:
                error_msg = f"No file path found for expert {instance.expert.name}"
                print(error_msg)
                return Response({'error': error_msg}, status=status.HTTP_400_BAD_REQUEST)

            if download_url:
                to_email = "timmyifidon@gmail.com" if settings.DEBUG else instance.user.email
                subject = f"Your EA: {instance.expert.name}"
                body = f"Hi {instance.user.full_name},\n\nYour expert advisor '{instance.expert.name}' is now available for download.\n\nDownload it here (expires in 1 hour):\n{download_url}\n\nBest,\nThe TradeVantage Team"

                send_email(to_email, subject, body)
            
            serializer = self.get_serializer(instance)
            return Response(serializer.data, status=status.HTTP_200_OK)
        # Custom logic: handle cancel via ?cancel=true
        if request.query_params.get("cancel") == "true":
            try:
                # Cancel Stripe subscription if it exists
                if instance.stripe_subscription_id:
                    stripe.api_key = settings.STRIPE_SECRET_KEY
                    try:
                        # Cancel at period end (this is the correct Stripe approach)
                        stripe.Subscription.modify(
                            instance.stripe_subscription_id,
                            cancel_at_period_end=True
                        )
                    except stripe.error.StripeError as e:
                        print(f"Failed to cancel Stripe subscription {instance.stripe_subscription_id}: {e}")
                        # Continue with local cancellation even if Stripe fails
                instance.state = "Cancelled"
                instance.save()
                
                # Send cancellation email
                try:
                    self.send_cancellation_email(instance)
                except Exception as e:
                    error_msg = f"Failed to send cancellation email: {str(e)}"
                    log_error(error_msg)

                
                serializer = self.get_serializer(instance)
                return Response(serializer.data, status=status.HTTP_200_OK)
                
            except Exception as e:
                return Response(
                    {'error': f'Failed to cancel subscription: {str(e)}'}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        return super().partial_update(request, *args, **kwargs)
    
    def send_cancellation_email(self, expert_user):
        try:
            expert = expert_user.expert
            subject = f"Subscription Cancelled: {expert.name}"
            
            body = f"""
Hi {expert_user.user.full_name},

Your subscription to {expert.name} has been successfully cancelled.

Subscription Details:
- Expert Advisor: {expert.name}
- Magic Number: {expert.magic_number}
- Cancelled Date: {timezone.now().strftime('%Y-%m-%d %H:%M:%S')}

Your access to this expert advisor will end immediately. You can resubscribe at any time by visiting our marketplace.

If you have any questions or need support, please don't hesitate to contact us.

Best regards,
The TradeVantage Team
"""
            
            to_email = expert_user.user.email
            send_email(to_email, subject, body)
            
        except Exception as e:
            error_msg = f"Failed to send cancellation email for expert {expert_user.expert.name}: {e}"
            print(error_msg)
            raise Exception(error_msg)

class SupabasePrivateUploadView(APIView):
    permission_classes = [IsProgrammerOrReadOnly]
    parser_classes = [MultiPartParser, FormParser]
    

    def post(self, request):
        import ast
        from storage3.exceptions import StorageApiError
        uploaded_files = request.FILES.getlist('files')
        if not uploaded_files:
            return Response({"error": "No files provided."}, status=400)

        access_token = request.headers.get('Authorization', '').split('Bearer ')[-1]
        supabase.auth.set_session(access_token, '')

        urls = {}

        for file in uploaded_files:
            try:
                if '-ex4' in file.name:
                    bucket = 'ea-uploads'
                elif '-image' in file.name:
                    bucket = 'ea-images'
                elif '-instructions' in file.name:
                    bucket = 'ea-instructions'
                else:
                    return Response({"error": f"Unrecognized file type in {file.name}"}, status=400)

                path = f"{request.user.id}/{file.name}"
                # Determine content type based on bucket
                if bucket == 'ea-uploads':
                    content_type = 'application/octet-stream'
                elif bucket == 'ea-images':
                    content_type = file.content_type or 'image/jpeg'
                elif bucket == 'ea-instructions':
                    content_type = file.content_type or 'application/pdf'
                else:
                    content_type = 'application/octet-stream'

                upload_response = supabase.storage.from_(bucket).upload(path, file.read(), {"content-type": content_type})

                if '-ex4' in file.name:
                    urls[file.name] = path
                else:
                    urls[file.name] = supabase.storage.from_(bucket).get_public_url(path)
            except StorageApiError as e:
                    return Response({"error": str(e)}, status=409)
            except Exception as e:
                return Response({"error": str(e)}, status=500)

            except Exception as e:
                return Response({"error": str(e)}, status=500)

        return Response({"uploaded": urls})
    
    def get(self, request):
        bucket = request.query_params.get('bucket')
        path = request.query_params.get('path')
        if not bucket or not path:
            return Response({'error': 'Bucket and path are required'}, status=400)
        try:
            file_data = supabase.storage.from_(bucket).download(path)
            return Response({'file': file_data.decode()}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)
        return Response({'error': 'File not found'}, status=404)
    
    def patch(self, request):
        bucket = request.data.get('bucket')
        path = request.data.get('path')
        file = request.FILES.get('file')

        if not bucket or not path or not file:
            return Response({'error': 'Bucket, path, and file are required'}, status=400)

        try:
            if bucket == 'ea-uploads':
                raw_content_type = getattr(file, 'content_type', None)
                content_type = raw_content_type if isinstance(raw_content_type, str) else 'application/octet-stream'
            elif bucket == 'ea-images':
                raw_content_type = getattr(file, 'content_type', None)
                content_type = raw_content_type if isinstance(raw_content_type, str) else 'image/jpeg'
            elif bucket == 'ea-instructions':
                raw_content_type = getattr(file, 'content_type', None)
                content_type = raw_content_type if isinstance(raw_content_type, str) else 'application/pdf'
            else:
                content_type = 'application/octet-stream'
            token = request.headers.get("Authorization", "").replace("Bearer ", "")
            file_options = {
                "content-type": content_type,
                "upsert": "true",  # Overwrite existing file
            }
            
            supabase.storage.from_(bucket).upload(path, file.read(), file_options)
            return Response({'message': 'File updated successfully'}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)

    def delete(self, request):
        bucket = request.query_params.get('bucket')
        path = request.query_params.get('path')
        if not bucket or not path:
            return Response({'error': 'Bucket and path are required'}, status=400)
        try:
            supabase.storage.from_(bucket).remove([path])
            return Response({'message': 'File deleted successfully'}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)


# Stripe Checkout Session Payments View
class PaymentsView(APIView):
    api_key = settings.STRIPE_SECRET_KEY
    stripe.api_key = api_key
    permission_classes = [IsAuthenticated]

    def store_transaction(self, transaction_data):
        serializer = ExpertUserSerializer(data=transaction_data, context={'request': self.request})
        serializer.is_valid(raise_exception=True)
        expert_user = serializer.save()
        return expert_user
    
    def post(self, request):
        expert_data = request.data.get('data')
        if not expert_data:
            return Response({'error': 'Expert data is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Get the expert advisor
            expert = ExpertAdvisor.objects.get(id=expert_data.get('id'))
            
            # Check if user already has access to this expert
            existing_subscription = ExpertUser.objects.filter(user=request.user, expert=expert, expires_at__gt=timezone.now()).first()
            if existing_subscription:
                return Response({'error': 'You already have access to this expert advisor'}, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if expert has a Stripe price ID
            if not expert.stripe_price_id:
                return Response({'error': 'This expert advisor is not available for purchase'}, status=status.HTTP_400_BAD_REQUEST)
            
            # Create Stripe checkout session
            session = stripe.checkout.Session.create(
                payment_method_types=['card'],
                mode='subscription',
                line_items=[{
                    'price': expert.stripe_price_id,
                    'quantity': 1,
                }],
                metadata={
                    'expert_id': str(expert.id),
                    'user_id': str(request.user.id),
                    'account_number': expert_data.get('account_number', "0")
                },
                success_url=f'{settings.FRONTEND_URL}/purchase-callback?session_id={{CHECKOUT_SESSION_ID}}',
                cancel_url=f'{settings.FRONTEND_URL}/market/{expert.id}/',
                customer_email=request.user.email
            )
    
            return Response({'url': session.url})
        except ExpertAdvisor.DoesNotExist:
            return Response({'error': 'Expert advisor not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    # Purchase Callback View
    def get(self, request):
        try:
            # Get the session_id from query parameters
            session_id = request.query_params.get('session_id')
            
            if not session_id:
                return Response({'error': 'Session ID is required'}, status=status.HTTP_400_BAD_REQUEST)
            
            # Retrieve the Stripe session to get metadata
            stripe.api_key = settings.STRIPE_SECRET_KEY
            session = stripe.checkout.Session.retrieve(session_id)
            
            # Extract expert_id and user_id from session metadata
            expert_id = session.metadata.get('expert_id')
            user_id = session.metadata.get('user_id')
            account_number = session.metadata.get('account_number')
            
            if not expert_id or not user_id or not account_number:
                return Response({'error': 'Invalid session metadata'}, status=status.HTTP_400_BAD_REQUEST)
            
            try: 
                # Get the ExpertUser record
                expert_user = self.store_transaction({'expert_id': expert_id, 'user_id': user_id, 'account_number': account_number})
                
                # Check if this is a new subscription (no last_paid_at)
                if not expert_user.last_paid_at:
                    # Set the subscription to active
                    expert_user.last_paid_at = timezone.now()
                    expert_user.state = "Active"
                    
                    # Store the Stripe subscription ID if available
                    if session.subscription:
                        expert_user.stripe_subscription_id = session.subscription
                    
                    expert_user.save()
                    
                    # Send email with EA file and instructions
                    try:
                        self.send_ea_email(expert_user)
                    except Exception as e:
                        error_msg = f"Failed to send EA email: {str(e)}"
                        log_error(error_msg)
                        return Response({'error': error_msg}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
                
                # Redirect to dashboard
                return Response({
                    'redirect_url': f'{settings.FRONTEND_URL}/dashboard',
                    'message': 'Purchase successful! You will receive an email with your EA file and instructions.'
                })
            except Exception as e:
                log_error(f"Failed to process purchase callback: {e}")
                if expert_user:
                    expert_user.delete()
                raise e
            
            
        except stripe.error.StripeError as e:
            return Response({'error': f'Stripe error: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)
        except ExpertUser.DoesNotExist:
            return Response({'error': 'ExpertUser record not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def send_ea_email(self, expert_user):
        try:
            # Get the expert advisor details
            expert = expert_user.expert
            
            # Generate download links for EA file and instructions
            ea_download_url = None
            instructions_download_url = None
            
            if expert.file:
                try:
                    # Construct the full path including user ID folder
                    expert_file_path = expert.file
                    if not expert_file_path.startswith(f"{expert.created_by.id}/"):
                        expert_file_path = f"{expert.created_by.id}/{expert_file_path}"
                    
                    # Generate signed URL for EA file (expires in 24 hours)
                    ea_download_url = supabase.storage.from_("ea-uploads").create_signed_url(
                        expert_file_path, 
                        86400  # 24 hours
                    ).get("signedURL")
                except Exception as e:
                    error_msg = f"Failed to generate EA file download URL for {expert_file_path}: {e}"
                    print(error_msg)
                    raise Exception(error_msg)
            else:
                error_msg = f"No file path found for expert {expert.name}"
                print(error_msg)
                raise Exception(error_msg)
            
            if expert.instructions:
                instructions_path = expert.instructions
                   
            
            # Prepare email content
            subject = f"Your EA: {expert.name} - Ready for Download"
            
            body = f"""
Hi {expert_user.user.full_name},

Your purchase of {expert.name} has been successfully processed!

Expert Advisor Details:
- Name: {expert.name}
- Magic Number: {expert.magic_number}
- Author: {expert.author}
- Version: {expert.version}

Download Links (expire in 24 hours):
"""
            
            if ea_download_url:
                body += f"\nEA File: {ea_download_url}"
            else:
                body += f"\nEA File: Not available at the moment (will be uploaded shortly)"
            
            if instructions_path:
                body += f"\nInstructions: {instructions_path}"
            else:
                body += f"\nInstructions: Not available at the moment (will be uploaded shortly)"
            
            body += f"""

Your subscription is active until: {expert_user.expires_at.strftime('%Y-%m-%d %H:%M:%S')}

If you have any questions or need support, please don't hesitate to contact us.

Best regards,
The TradeVantage Team
"""
            
            # Send email
            to_email = expert_user.user.email
            send_email(to_email, subject, body)
            
        except Exception as e:
            error_msg = f"Failed to send EA email for expert {expert_user.expert.name}: {e}"
            print(error_msg)
            raise Exception(error_msg)

# Stripe Webhook View to handle Stripe webhook events
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.utils.timezone import now
from datetime import timedelta

@method_decorator(csrf_exempt, name='dispatch')
class StripeWebhookView(APIView):
    permission_classes = []

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
        endpoint_secret = settings.STRIPE_WEBHOOK_SECRET

        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, endpoint_secret
            )
        except ValueError as e:
            return Response({'error': 'Invalid payload'}, status=400)
        except stripe.error.SignatureVerificationError as e:
            return Response({'error': 'Invalid signature'}, status=400)

        if event['type'] == 'checkout.session.completed':
            # Handle successful checkout completion (backup mechanism)
            session = event['data']['object']
            subscription_id = session.get('subscription')
            customer_email = session.get('customer_email') or session.get('customer_details', {}).get('email')
            metadata = session.get('metadata', {})
            
            # Only process if this is a subscription (has subscription_id)
            if subscription_id and metadata:
                expert_id = metadata.get('expert_id')
                user_id = metadata.get('user_id')
                account_number = metadata.get('account_number', "0")
                
                try:
                    user = User.objects.get(id=user_id, email=customer_email)
                    expert = ExpertAdvisor.objects.get(id=expert_id)
                    
                    # Check if ExpertUser already exists (avoid duplicates)
                    expert_user = ExpertUser.objects.filter(
                        user=user, 
                        expert=expert, 
                        stripe_subscription_id=subscription_id
                    ).first()
                    
                    if not expert_user:
                        # Create ExpertUser record if it doesn't exist
                        expert_user = ExpertUser.objects.create(
                            user=user,
                            expert=expert,
                            account_number=account_number,
                            stripe_subscription_id=subscription_id,
                            last_paid_at=now(),
                            state="Active"
                        )
                        log_user_action(user, "subscription_created", f"Subscription created via webhook for {expert.name}")
                        print(f"Created ExpertUser via checkout.session.completed webhook for {customer_email}")
                    else:
                        # Update existing record if subscription_id wasn't set
                        if not expert_user.stripe_subscription_id:
                            expert_user.stripe_subscription_id = subscription_id
                            expert_user.last_paid_at = now()
                            expert_user.state = "Active"
                            expert_user.save()
                            print(f"Updated ExpertUser subscription_id via webhook for {customer_email}")
                            
                except User.DoesNotExist:
                    log_error(f"User not found in checkout.session.completed webhook: {customer_email}, user_id: {user_id}")
                except ExpertAdvisor.DoesNotExist:
                    log_error(f"ExpertAdvisor not found in checkout.session.completed webhook: expert_id: {expert_id}")
                except Exception as e:
                    log_error(f"Error handling checkout.session.completed: {e}")
                    
        elif event['type'] == 'customer.subscription.created':
            # Handle subscription creation (backup for initial subscription)
            # Note: This fires when subscription is created, but we prefer checkout.session.completed
            # because it has all the metadata. This is mainly for logging/backup.
            subscription = event['data']['object']
            subscription_id = subscription.get('id')
            customer_id = subscription.get('customer')
            
            # Try to find existing ExpertUser by subscription_id
            expert_user = ExpertUser.objects.filter(stripe_subscription_id=subscription_id).first()
            
            if not expert_user and customer_id:
                # Try to find by customer if subscription_id not set yet
                try:
                    # Set API key for Stripe call
                    stripe.api_key = settings.STRIPE_SECRET_KEY
                    # Get customer email from Stripe
                    customer = stripe.Customer.retrieve(customer_id)
                    customer_email = getattr(customer, 'email', None)
                    
                    if customer_email:
                        # Find user by email
                        user = User.objects.get(email=customer_email)
                        
                        # Log that we found a new subscription but can't create ExpertUser without metadata
                        log_error(f"customer.subscription.created received but no ExpertUser found. Subscription: {subscription_id}, User: {customer_email}. ExpertUser should be created via checkout.session.completed or purchase callback.")
                except User.DoesNotExist:
                    log_error(f"customer.subscription.created: User not found for email: {customer_email}")
                except Exception as e:
                    log_error(f"Error handling customer.subscription.created: {e}")
                    
        elif event['type'] == 'invoice.paid':
            invoice = event['data']['object']
            customer_email = invoice.get('customer_email')
            subscription_id = invoice.get('subscription')

            try:
                user = User.objects.get(email=customer_email)
                
                # Find the ExpertUser record for this subscription
                expert_user = ExpertUser.objects.filter(user=user, stripe_subscription_id=subscription_id).first()
                if expert_user:
                    expert_user.last_paid_at = now()
                    expert_user.expires_at = expert_user.last_paid_at + timedelta(days=30)
                    expert_user.save()
                else:
                    # If no ExpertUser record exists, create one based on the session metadata
                    # This would typically be handled by the checkout session completion
                    pass
                    
            except User.DoesNotExist:
                log_error(f"Payment process for user {customer_email} failed on subscription {subscription_id}")
                return Response({'error': 'User not found'}, status=404)
                
        elif event['type'] == 'invoice.payment_failed':
            invoice = event['data']['object']
            subscription_id = invoice.get('subscription')
            customer_email = invoice.get('customer_email')
            
            try:
                # Find the ExpertUser record for this subscription
                expert_user = ExpertUser.objects.filter(stripe_subscription_id=subscription_id).first()
                if expert_user:
                    # Update state to indicate payment failure
                    expert_user.state = "Payment Failed"
                    expert_user.save()
                    
                    # Send notification email about failed payment
                    try:
                        send_email(
                            to_email=customer_email,
                            subject="Payment Failed - Please Update Your Payment Method",
                            message=f"""
                            We attempted to charge your payment method for utility {expert_user.expert.name}, but the payment failed.
                            
                            Please update your payment method in Stripe or contact support if you need assistance.
                            
                            Your subscription will remain active until {expert_user.expires_at} if payment is not received.
                            """
                        )
                    except Exception as e:
                        log_error(f"Failed to send payment failure email: {str(e)}")
                    
                    log_user_action(expert_user.user, "payment_failed", f"Payment failed for {expert_user.expert.name}")
                    print(f"Payment failed for subscription {subscription_id}, user {customer_email}")
                else:
                    print(f"No ExpertUser record found for subscription {subscription_id}")
                    
            except Exception as e:
                log_error(f"Error handling payment failure: {e}")
                
        elif event['type'] == 'customer.subscription.deleted':
            subscription = event['data']['object']
            subscription_id = subscription.get('id')
            
            try:
                # Find the ExpertUser record for this subscription
                expert_user = ExpertUser.objects.filter(stripe_subscription_id=subscription_id).first()
                if expert_user:
                    # Set expiration to now (immediate cancellation)
                    expert_user.expires_at = timezone.now()
                    expert_user.state = "Cancelled"
                    expert_user.save()
                    
                    log_user_action(expert_user.user, "subscription_cancelled", f"Cancelled subscription to {expert_user.expert.name}")
                    print(f"Subscription {subscription_id} cancelled for user {expert_user.user.email}")
                else:
                    print(f"No ExpertUser record found for subscription {subscription_id}")
                    
            except Exception as e:
                log_error(f"Error handling subscription deletion: {e}")
                
        elif event['type'] == 'customer.subscription.updated':
            subscription = event['data']['object']
            subscription_id = subscription.get('id')
            status = subscription.get('status')
            
            try:
                expert_user = ExpertUser.objects.filter(stripe_subscription_id=subscription_id).first()
                if expert_user:
                    # Update state based on Stripe subscription status
                    if status == 'active':
                        expert_user.state = "Active"
                    elif status == 'past_due':
                        expert_user.state = "Past Due"
                    elif status == 'unpaid':
                        expert_user.state = "Unpaid"
                    elif status == 'canceled':
                        expert_user.state = "Cancelled"
                    
                    expert_user.save()
                    log_user_action(expert_user.user, "subscription_updated", f"Subscription status updated to {status}")
                    
            except Exception as e:
                log_error(f"Error handling subscription update: {e}")

        return Response({'status': 'success'}, status=200)
