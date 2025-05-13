from rest_framework import generics
from .models import User
from .serializers import RegisterSerializer, UserSerializer
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

class RegisterView(generics.CreateAPIView):
    """
    | POST   | `/api/register/`        | Create a new user account (Supabase first) |
    """
    queryset = User.objects.all()
    serializer_class = RegisterSerializer

    def create(self, request, *args, **kwargs):
        from tv_backend import settings
        from supabase import create_client

        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

        data = request.data.copy()
        email = data.get("email", "").strip().lower()
        password = data.get("password")

        if not data.get("mock"):
            supabase_signup_res = supabase.auth.sign_up({
                "email": email,
                "password": password,
                "options": {
                    "data": {
                        "role": data.get("role")
                    }
                }
            })

            if not supabase_signup_res.get("user"):
                return Response({"error": "Supabase signup failed", "details": supabase_signup_res}, status=400)

            supabase_user = supabase_signup_res.get("user")
            supabase_uid = supabase_user.get("id") if supabase_user else None

            if not supabase_uid:
                return Response({"error": "Invalid Supabase response"}, status=500)

            data["id"] = supabase_uid

        if not data.get("username"):
            data["username"] = email

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(serializer.data, status=201)
    
class LoginUserView(generics.RetrieveAPIView):
    """
    GET /api/user/ -> return the authenticated user’s profile.
    """
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):        
        return self.request.user