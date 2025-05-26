import jwt
from rest_framework import authentication, exceptions
from tv_backend.settings import SUPABASE_JWT_SECRET
from accounts.models import User 

class SupabaseJWTAuthentication(authentication.BaseAuthentication):
    def authenticate(self, request):
        auth_header = authentication.get_authorization_header(request).split()

        if not auth_header or auth_header[0].lower() != b'bearer':
            return None

        if len(auth_header) == 1 or len(auth_header) > 2:
            raise exceptions.AuthenticationFailed('Invalid token header')

        token = auth_header[1].decode()

        try:
            payload = jwt.decode(
                token,
                SUPABASE_JWT_SECRET, 
                algorithms=["HS256"],
                audience="authenticated"
            )
        except jwt.ExpiredSignatureError:
            raise exceptions.AuthenticationFailed('Token has expired')
        except jwt.InvalidTokenError:
            raise exceptions.AuthenticationFailed('Invalid token')

        try:
            user = User.objects.get(id=payload['sub'])
        except User.DoesNotExist:
            raise exceptions.AuthenticationFailed('User not found')

        from accounts.supabase_client import supabase
        supabase.auth.set_session(token, "")


        return (user, None)