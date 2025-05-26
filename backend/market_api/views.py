import stripe
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
from tv_backend.email_client import send_email

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
    update, or delete, while allowing read-only access to any authenticated user.
    """
    def has_permission(self, request, view):
        # Allow safe methods for any authenticated user
        if request.method in SAFE_METHODS:
            return bool(request.user and request.user.is_authenticated)
        # Allow others only if user is authenticated and role is programmer
        return bool(request.user and request.user.is_authenticated and getattr(request.user, 'role', None) == 'programmer')

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
        queryset = ExpertAdvisor.objects.annotate(
            download_count=Count('downloads')
        )
        if self.request.query_params.get('owned') == 'true' and user.is_authenticated:
            queryset = queryset.filter(created_by=user)
        return queryset

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
        # Custom logic: handle renew via ?renew=true
        if request.query_params.get("renew") == "true":
            instance.last_paid_at = timezone.now()
            instance.expires_at = instance.thirty_days_from_now()
            instance.save()
            serializer = self.get_serializer(instance)
            return Response(serializer.data, status=status.HTTP_200_OK)
        # Custom logic: handle push via ?push=true
        if request.query_params.get("push") == "true":
            instance.last_paid_at = timezone.now()
            instance.expires_at = instance.thirty_days_from_now()
            instance.save()
            # Generate signed download link and send email
            expert_file_path = instance.expert.file  # This should be the path stored in the 'file' field
            download_url = supabase.storage.from_("ea-uploads").create_signed_url(expert_file_path, 3600).get("signedURL")

            to_email = "timmyifidon@gmail.com" if settings.DEBUG else instance.user.email
            subject = f"Your EA: {instance.expert.name}"
            body = f"Hi {instance.user.full_name},\n\nYour expert advisor '{instance.expert.name}' is now available for download.\n\nDownload it here (expires in 1 hour):\n{download_url}\n\nBest,\nThe TradeVantage Team"

            send_email(to_email, subject, body)
            serializer = self.get_serializer(instance)
            
            return Response(serializer.data, status=status.HTTP_200_OK)
        return super().partial_update(request, *args, **kwargs)

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

''' Implment later: Stripe payment for subscriptions
# Stripe Checkout Session Payments View
class PaymentsView(APIView):
    api_key = settings.STRIPE_SECRET_KEY
    stripe.api_key = api_key
    permission_classes = [IsAuthenticated]

    def store_transaction(self, transaction_data):
        serializer = ExpertUserSerializer(data=transaction_data, context={'request': self.request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
    
    
    def post(self, request):
        expert_data = request.data.get('expert_data')
        try:
            session = stripe.checkout.Session.create(
                payment_method_types=['card'],
                mode='subscription',
                line_items=[{
                    'price': expert_data.get('stripe_price_id'),  # should be stored with the ExpertAdvisor
                    'quantity': 1,
                }],
                metadata={
                    'expert_id': expert_data.get('id')
                },
                success_url=f'{settings.FRONTEND_URL}/dashboard/',
                cancel_url=f'{settings.FRONTEND_URL}/market/{expert_data.get("id")}/',
                customer_email=request.user.email
            )
            # Store transaction in the database giving user permission
            transaction = {
                'id': session.subscription,
                'expert': ExpertAdvisor.objects.get(id=expert_data.get("id")),
            }
            
            self.store_transaction(transaction)
            return Response({'url': session.url})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

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

        if event['type'] == 'invoice.paid':
            invoice = event['data']['object']
            customer_email = invoice.get('customer_email')

            try:
                user = User.objects.get(email=customer_email)
                subscription_id = invoice.get('subscription')

                # You could optionally verify subscription ID with your own DB
                expert_user = ExpertUser.objects.filter(id=subscription_id)
                expert_user.last_paid_at = now()
                expert_user.expires_at += timedelta(days=30)
                expert_user.save()
            except User.DoesNotExist:
                return Response({'error': 'User not found'}, status=404)
            except ExpertUser.DoesNotExist:
                return Response({'error': 'ExpertUser record not found'}, status=404)
        elif event['type'] == 'customer.subscription.deleted':
            subscription = event['data']['object']
            subscription_id = subscription.get('id')

            # try:
            #     pass
                
            # except ExpertUser.DoesNotExist:
            #     return Response({'error': 'ExpertUser record not found'}, status=404)

        return Response({'status': 'success'}, status=200)
'''
