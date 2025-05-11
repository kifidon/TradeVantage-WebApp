from rest_framework import generics
from .models import User
from .serializers import RegisterSerializer, UserSerializer
from rest_framework.permissions import IsAuthenticated

class RegisterView(generics.CreateAPIView):
    """
    | POST   | `/api/register/`        | Create a new user account           |
    | POST   | `/api/login/`           | Obtain JWT access & refresh tokens  |
    | POST   | `/api/login/refresh/`   | Refresh an access token           
    """
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    
class LoginUserView(generics.RetrieveAPIView):
    """
    GET /api/user/ -> return the authenticated user’s profile.
    """
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):        return self.request.user