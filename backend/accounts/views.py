from rest_framework import generics
from rest_framework.views import APIView
from .models import User
from .serializers import RegisterSerializer, UserSerializer
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
from tv_backend.logger import get_logger, log_user_action, log_request
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
            from gotrue.errors import AuthApiError, AuthWeakPasswordError
            # Handle specific password validation errors
            if isinstance(e, AuthWeakPasswordError):
                error_msg = "Password must contain at least one character from each of the following: lowercase letters (a-z), uppercase letters (A-Z), numbers (0-9), and special characters (!@#$%^&*()_+-=[]{};':\"|<>?,./`~.)."
                return None, {"error": error_msg}, 422
            
            # Determine status code from exception or response
            status_code = getattr(e, "status_code", None) or getattr(getattr(e, "response", None), "status_code", None)
            # Determine message
            msg = getattr(e, "message", None) or str(e)
            
            # Handle AuthApiError specifically
            if isinstance(e, AuthApiError):
                # Check if it's a weak password error
                error_str = str(e).lower()
                if "weak password" in error_str or "password should contain" in error_str:
                    error_msg = "Password must contain at least one character from each of the following: lowercase letters (a-z), uppercase letters (A-Z), numbers (0-9), and special characters (!@#$%^&*()_+-=[]{};':\"|<>?,./`~.)."
                    return None, {"error": error_msg}, 422
                
                # Use status code from exception or default to 422 for validation errors
                if status_code == 400:
                    # Check if it's a validation error masquerading as 400
                    if "password" in error_str:
                        error_msg = "Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character."
                        return None, {"error": error_msg}, 422
                    return None, {"error": f"Invalid request: {msg}"}, 400
                elif status_code == 401:
                    return None, {"error": f"Unauthorized: {msg}"}, 401
                elif status_code == 404:
                    return None, {"error": f"Resource not found: {msg}"}, 404
                elif status_code == 409:
                    if "email" in error_str or "already exists" in error_str:
                        return None, {"error": "An account with this email already exists. Please login instead."}, 409
                    return None, {"error": f"Conflict: {msg}"}, 409
                elif status_code == 422:
                    if "password" in error_str:
                        error_msg = "Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character."
                        return None, {"error": error_msg}, 422
                    return None, {"error": msg}, 422
                elif status_code == 429:
                    return None, {"error": "Too many signup attempts. Please wait a few minutes before trying again."}, 429
                else:
                    # Default to 422 for validation errors from AuthApiError
                    if "password" in error_str or "weak" in error_str:
                        error_msg = "Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character."
                        return None, {"error": error_msg}, 422
                    logger.exception("Unexpected AuthApiError during Supabase signup")
                    return None, {"error": msg}, status_code or 422
            
            # Handle other exceptions
            if status_code == 400:
                return None, {"error": f"Bad request: {msg}"}, 400
            elif status_code == 401:
                return None, {"error": f"Unauthorized: {msg}"}, 401
            elif status_code == 404:
                return None, {"error": f"Resource not found: {msg}"}, 404
            elif status_code == 409:
                return None, {"error": f"Conflict: {msg}"}, 409
            elif status_code == 422:
                return None, {"error": msg}, 422
            # Fallback for other cases
            logger.exception("Unexpected error during Supabase signup")
            return None, {"error": msg}, status_code or 500
            

    def create(self, request, *args, **kwargs):
        logger = get_logger()
        log_request(request, "RegisterView.create")
        
        data = request.data.copy()
        email = data.get("email", "").strip().lower()
        role = data.get("role", "user")

        supabase_uid, error, code = self.supabase_signup(data)

        if error:
            logger.warning(f"Registration failed for {email}: {error}")
            return Response(error, status=code)

        if not supabase_uid:
            logger.error(f"Registration failed for {email}: No Supabase UID returned")
            return Response({"error": "Invalid Response. Please try again later"}, status=500)

        data["id"] = supabase_uid
        if not data.get("username"):
            data["username"] = email

        serializer = self.get_serializer(data=data)
        try: 
            serializer.is_valid(raise_exception=True)
            self.perform_create(serializer)
            logger.info(f"User registered successfully: {email} with role: {role}")
            log_user_action(email, "user_registered", f"Role: {role}")
            return Response(serializer.data, status=201)
        except ValidationError as e:
            logger.warning(f"Registration validation error for {email}: {e}")
            return Response({"error": {"A user with this email/username already exists"}}, status=409)
        except Exception as e:
            logger.error(f"Registration server error for {email}: {e}")
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
        logger = get_logger()
        log_request(request, "SupaBaseLoginView.post")
        
        data = request.data.copy()
        email = data.get("email", "").strip().lower()
        password = data.get("password")

        if not email or not password:
            logger.warning(f"Login attempt with missing credentials")
            return Response({"error": "Email and password are required"}, status=400)

        user_data, result = self.login(email, password)

        # Check if login failed (result is a dict with 'error' key)
        if not user_data or not result or isinstance(result, dict):
            error_msg = result.get('error', 'Invalid email or password') if isinstance(result, dict) else 'Invalid email or password'
            logger.warning(f"Login failed for {email}: {error_msg}")
            return Response({"error": error_msg}, status=401)

        # Check if user exists in Django database
        try:
            user = User.objects.get(id=user_data.id)
        except User.DoesNotExist:
            logger.error(f"User {email} authenticated with Supabase but not found in Django database")
            return Response({"error": "User not found in database. Please contact support."}, status=401)
        except Exception as e:
            logger.error(f"Database error during login for {email}: {str(e)}")
            return Response({"error": "Database error occurred"}, status=500)

        serializer = UserSerializer(user)
        logger.info(f"User {email} logged in successfully")
        log_user_action(email, "user_login", "User logged in")
        
        return Response({
            "user": serializer.data,
            "access_token": result.access_token,
            "refresh_token": result.refresh_token
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
            
            # Check if Supabase returned an error
            if hasattr(login_res, 'error') and login_res.error:
                return None, {"error": str(login_res.error)}
            
        except Exception as e:
            return None, {"error": "Invalid email or password"}
        return login_res.user, login_res.session
    
class RetrievUserView(generics.RetrieveAPIView):
    """
    GET /api/user/ -> return the authenticated user’s profile.
    """
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):        
        return self.request.user