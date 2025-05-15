from rest_framework import generics
from rest_framework.views import APIView
from .models import User
from .serializers import RegisterSerializer, UserSerializer
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

class RegisterView(generics.CreateAPIView):
    """
    | POST   | `/api/register/`        | Create a new user account (Supabase first) |
    """
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def supabase_signup(self, data):
        from tv_backend import settings
        from supabase import create_client

        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

        email = data.get("email", "").strip().lower()
        password = data.get("password")

        supabase_signup_res = supabase.auth.sign_up({
            "email": email,
            "password": password,
            "options": {
                "data": {
                    "role": data.get("role")
                }
            }
        })

        if not type(supabase_signup_res).model_fields:
            return None, supabase_signup_res

        supabase_user = supabase_signup_res.user
        supabase_uid = supabase_user.id if supabase_user else None

        return supabase_uid, None

    def create(self, request, *args, **kwargs):
        data = request.data.copy()
        email = data.get("email", "").strip().lower()

        supabase_uid, error = self.supabase_signup(data)

        if error:
            return Response({"error": "Supabase signup failed", "details": error}, status=400)

        if not supabase_uid:
            return Response({"error": "Invalid Supabase response"}, status=500)

        data["id"] = supabase_uid
        if not data.get("username"):
            data["username"] = email

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(serializer.data, status=201)
    
class SupaBaseLoginView(APIView):
    """
    | POST   | `/api/login/`           | Login user and return JWT token |
    """
    permission_classes = [AllowAny]
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        from supabase import create_client
        from tv_backend import settings
        self.supa_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

    def post(self, request, *args, **kwargs):
        data = request.data.copy()
        email = data.get("email", "").strip().lower()
        password = data.get("password")

        user_data, session = self.login(email, password)

        if not user_data or not session:
            return Response({"error": "Login failed"}, status=401)

        user = User.objects.get(id=user_data.id)
        serializer = UserSerializer(user)
        return Response({
            "user": serializer.data,
            "access_token": session.access_token,
            "refresh_token": session.refresh_token
        }, status=200)
    
    def login(self, email, password):
        try:
            login_res = self.supa_client.auth.sign_in_with_password({
                "email": email,
                "password": password
            })
        except Exception as e:
            return None, {"error": str(e)}
        return login_res.user, login_res.session
    
class RetrievUserView(generics.RetrieveAPIView):
    """
    GET /api/user/ -> return the authenticated user’s profile.
    """
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):        
        return self.request.user