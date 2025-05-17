import stripe
from django.conf import settings
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

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
from tv_backend.settings import SUPABASE_URL, SUPABASE_KEY
from django.db.models import Count
from rest_framework.permissions import IsAuthenticated, BasePermission, SAFE_METHODS
import requests
from supabase import create_client

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
        experts = ExpertAdvisor.objects.annotate(
            download_count=Count('downloads')  # reverse FK from ExpertUser
        )
        return experts 

class ExpertUserViewSet(ModelViewSet):
    serializer_class = ExpertUserSerializer
    permission_classes = [IsAuthenticated]
    queryset = ExpertUser.objects.all()

    def get_queryset(self):
        return ExpertUser.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        expert = serializer.validated_data.get('expert')
        existing = ExpertUser.objects.filter(user=self.request.user, expert=expert).exists()
        if existing:
            raise serializer.ValidationError("You are already subscribed to this Expert Advisor.")
        serializer.save(user=self.request.user)

class SupabasePrivateUploadView(APIView):
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    permission_classes = [IsProgrammerOrReadOnly]
    parser_classes = [MultiPartParser, FormParser]
    

    def post(self, request):
        import ast
        from storage3.exceptions import StorageApiError
        uploaded_files = request.FILES.getlist('files')
        if not uploaded_files:
            return Response({"error": "No files provided."}, status=400)

        access_token = request.headers.get('Authorization', '').split('Bearer ')[-1]
        self.supabase.auth.set_session(access_token, '')

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
                upload_response = self.supabase.storage.from_(bucket).upload(path, file.read())

                if '-ex4' in file.name:
                    urls[file.name] = path
                else:
                    urls[file.name] = self.supabase.storage.from_(bucket).get_public_url(path)
            except StorageApiError as e:
                    return Response({"error": str(e)}, status=409)
            except Exception as e:
                return Response({"error": str(e)}, status=500)

            except Exception as e:
                return Response({"error": str(e)}, status=500)

        return Response({"uploaded": urls})
    
    def get(self, request):
        bucket = request.data.get('bucket')
        path = request.data.get('path')
        if not bucket or not path:
            return Response({'error': 'Bucket and path are required'}, status=400)
        try:
            file_data = self.supabase.storage.from_(bucket).download(path)
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
            self.supabase.storage.from_(bucket).upload(path, file.read(), {"upsert": True})
            return Response({'message': 'File updated successfully'}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)

    def delete(self, request):
        bucket = request.data.get('bucket')
        path = request.data.get('path')
        if not bucket or not path:
            return Response({'error': 'Bucket and path are required'}, status=400)
        try:
            self.supabase.storage.from_(bucket).remove([path])
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
