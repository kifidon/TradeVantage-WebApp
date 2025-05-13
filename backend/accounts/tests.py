from rest_framework.test import APITestCase
from rest_framework import status
from accounts.models import User
from unittest.mock import patch, MagicMock
from accounts.views import SupaBaseLoginView

class UserRegistrationTest(APITestCase):
    @patch("accounts.views.RegisterView.supabase_signup")
    def test_register_user_successfully(self, mock_supabase_signup):
        mock_supabase_signup.return_value = ("33a78ee6-12f6-46d5-8b68-6e50563b906c", None)
        data = {
            "email": "testuser@gmail.com",
            "username": "testuser",
            "full_name": "Test User",
            "password": "securepassword123",
            "role": "programmer",

        }
        response = self.client.post("/api/register/", data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(email="testuser@gmail.com").exists())
        self.assertEqual(User.objects.get(email="testuser@gmail.com").role, "programmer")
    


class UserLoginTest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="existing@example.com",
            username="existing@example.com",
            full_name="Existing User",
            password="securepass",
            role="user"
        )

    @patch("accounts.views.SupaBaseLoginView.login")
    @patch.object(SupaBaseLoginView, "get_object")
    def test_login_user_successfully(self, mock_get_object, mock_login):
        mock_login.return_value = (
            {
                "id": "dummy-id",
                "email": "existing@example.com"
            },
            {
                "session": {
                    "access_token": "dummy-access-token",
                    "refresh_token": "dummy-refresh-token"
                }
            }
        )
        mock_get_object.return_value = self.user
        data = {
            "email": "existing@example.com",
            "username": "existing@example.com",
            "password": "securepass"
        }
        response = self.client.post("/api/login/", data)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access_token", response.data)
        self.assertIn("refresh_token", response.data)

    @patch("accounts.views.SupaBaseLoginView.login")
    def test_login_with_wrong_password(self, mock_supa_client):
        mock_supa_client.return_value = None, None
        data = {
            "email": "existing@example.com",
            "username": "existing@example.com",
            "password": "wrongpass"
        }
        response = self.client.post("/api/login/", data)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)