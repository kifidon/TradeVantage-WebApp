from rest_framework.test import APITestCase
from rest_framework import status
from accounts.models import User

class UserRegistrationTest(APITestCase):
    def test_register_user_successfully(self):
        data = {
            "email": "testuser@gmail.com",
            "username": "testuser",
            "full_name": "Test User",
            "password": "securepassword123",
            "role": "programmer",
            "mock": True  # Mocking the Supabase signup
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

    def test_login_user_successfully(self):
        data = {
            # "email": "existing@example.com",
            "username": "existing@example.com",
            "password": "securepass"
        }
        response = self.client.post("/api/login/", data)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)

    def test_login_with_wrong_password(self):
        data = {
            "email": "existing@example.com",
            "username": "existing@example.com",
            "password": "wrongpass"
        }
        response = self.client.post("/api/login/", data)

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        
        