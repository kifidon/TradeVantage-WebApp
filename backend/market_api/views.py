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

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


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
                upload_response = supabase.storage.from_(bucket).upload(path, file.read())

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
        bucket = request.data.get('bucket')
        path = request.data.get('path')
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
            supabase.storage.from_(bucket).upload(path, file.read(), {"upsert": True})
            return Response({'message': 'File updated successfully'}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)

    def delete(self, request):
        bucket = request.data.get('bucket')
        path = request.data.get('path')
        if not bucket or not path:
            return Response({'error': 'Bucket and path are required'}, status=400)
        try:
            supabase.storage.from_(bucket).remove([path])
            return Response({'message': 'File deleted successfully'}, status=200)
        except Exception as e:
            return Response({'error': str(e)}, status=500)