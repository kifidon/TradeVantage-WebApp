from rest_framework import generics
from rest_framework.views import APIView
from .models import User
from .serializers import RegisterSerializer, UserSerializer
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
import os

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
        import logging
        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        logger = logging.getLogger(__name__)

        email = data.get("email", "").strip().lower()
        password = data.get("password")
        try:
            supabase_signup_res = supabase.auth.sign_up({
                "email": email,
                "password": password,
                "options": {"data": {"role": data.get("role")}}
            })
            status_code = getattr(supabase_signup_res, "status_code", None)
            # Handle Supabase response error
            error = getattr(supabase_signup_res, "error", None)
            if error:
                logger.error("Supabase signup error: %s", error)
                return None, {"error": error}, status_code or 400
            # Ensure user object exists
            supabase_user = getattr(supabase_signup_res, "user", None)
            if not supabase_user or not hasattr(supabase_user, "id"):
                logger.error("Supabase signup returned no user: %s", supabase_signup_res)
                return None, {"error": "Invalid user data from Supabase"}, status_code or 500
            return supabase_user.id, None, status_code or 201
        except Exception as e:
            # Determine status code from exception or response
            status_code = getattr(e, "status_code", None) or getattr(getattr(e, "response", None), "status_code", None)
            # Determine message
            msg = getattr(e, "message", None) or str(e)
            if status_code == 400:
                return None, {"error": f"Bad request: {msg}"}, 400
            elif status_code == 401:
                return None, {"error": f"Unauthorized: {msg}"}, 401
            elif status_code == 404:
                return None, {"error": f"Resource not found: {msg}"}, 404
            elif status_code == 409:
                return None, {"error": f"Conflict: {msg}"}, 409
            elif status_code == 422:
                return None, {"error": f"Unprocessable entity: {msg}"}, 422
            # Fallback for other cases
            logger.exception("Unexpected error during Supabase signup")
            return None, {"error": msg}, status_code or 500
            

    def create(self, request, *args, **kwargs):
        data = request.data.copy()
        email = data.get("email", "").strip().lower()

        supabase_uid, error, code = self.supabase_signup(data)

        if error:
            return Response(error, status=code)

        if not supabase_uid:
            return Response({"error": "Invalid Response. Please try again later"}, status=500)

        data["id"] = supabase_uid
        if not data.get("username"):
            data["username"] = email

        serializer = self.get_serializer(data=data)
        try: 
            serializer.is_valid(raise_exception=True)
            self.perform_create(serializer)
            return Response(serializer.data, status=201)
        except ValidationError as e:
            return Response({"error": {"A user with this email/username already exists"}}, status=409)
        except Exception as e:
            return Response({"error": "Oops, There was a problem on the server. Please try again later."}, status=500)
    
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
            return Response({"error": {session['error']}}, status=401)

        user = User.objects.get(id=user_data.id)
        serializer = UserSerializer(user)
        return Response({
            "user": serializer.data,
            "access_token": session.access_token,
            "refresh_token": session.refresh_token
        }, status=200)
    
    def patch(self, request, *args, **kwargs):
        """
        Handle PATCH: Resend Supabase signup confirmation email.
        """
        email = request.data.get("email", "").strip().lower()
        if not email:
            return Response({"error": "Email is required to resend confirmation."}, status=400)
        try:
            frontend_url = os.environ.get("FRONTEND_URL", "")
            # Generate a new signup confirmation link
            result = self.supa_client.auth.admin.generate_link(
                params={
                "type": "signup",                                 
                "email": email,
                "options": {
                    "redirectTo": f"{frontend_url}/login"}  
                }
            )
            # Supabase returns {'data': {...}, 'error': None}
            error = result.get("error")
            if error:
                return Response({"error": error}, status=result.get("statusCode", 400))
            link = result.get("data", {}).get("longUrl")
            return Response({"message": "Confirmation link generated.", "link": link}, status=200)
        except Exception as e:
            return Response({"error": str(e)}, status=500)
    
    
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