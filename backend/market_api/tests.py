from rest_framework.test import APITestCase
from rest_framework import status
from .models import ExpertAdvisor
from .models import ExpertUser
from django.contrib.auth import get_user_model
from datetime import timedelta
from django.utils import timezone
import json


class ExpertAdvisorTests(APITestCase):
    def setUp(self):
        # Register and log in a test user to obtain JWT token
        user_data = {
            "email": "testuser@example.com",
            "full_name": "Test User",
            "password": "securepassword123",
            "role": "programmer"
        }
        self.client.post("/api/register/", user_data, format='json')
        login_resp = self.client.post(
            "/api/login/",
            {"email": user_data["email"], "password": user_data["password"]},
            format='json'
        )
        self.token = login_resp.data["access"]
        # Include token in Authorization header for subsequent requests
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.token}')
        # Create 20 mock ExpertAdvisors with varying values
        for i in range(20):
            ExpertAdvisor.objects.create(
                name=f"EA {i}",
                description=f"This is description {i}",
                version="1.0",
                author=f"Author {i % 5}",
                created_at=timezone.now() - timedelta(days=i),
                updated_at=timezone.now() - timedelta(days=i),
                image_url=f"https://example.com/image{i}.png",
                file_url=f"https://example.com/file{i}.ex4", 
            )

    def test_create_valid_expert_advisor(self):
        """Test creating an Expert Advisor with valid data should succeed (201 Created)."""
        data = {
            "name": "Valid EA",
            "description": "A valid EA",
            "version": "1.0",
            "author": "Test Author",
            "image_url": "https://example.com/image.png",
            "file_url": "https://example.com/ea.ex4"
        }
        response = self.client.post("/api/experts/", data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_create_invalid_image_url(self):
        """Test creating an Expert Advisor with an invalid image_url should fail (400 Bad Request)."""
        data = {
            "name": "Invalid Image",
            "description": "Test EA",
            "version": "1.0",
            "author": "Test Author",
            "image_url": "not-a-url",
            "file_url": "https://example.com/ea.ex4"
        }
        response = self.client.post("/api/experts/", data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_create_invalid_file_url(self):
        """Test creating an Expert Advisor with an invalid file_url should fail (400 Bad Request)."""
        data = {
            "name": "Invalid File",
            "description": "Test EA",
            "version": "1.0",
            "author": "Test Author",
            "image_url": "https://example.com/image.png",
            "file_url": "not-a-url"
        }
        response = self.client.post("/api/experts/", data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_get_default_page(self):
        """Test default GET request returns first 10 EAs due to default page size."""
        response = self.client.get("/api/experts/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 10)

    def test_get_custom_page_size_20(self):
        """Test GET request with page_size=20 returns exactly 20 results."""
        response = self.client.get("/api/experts/?page_size=20")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 20)

    def test_get_page_size_100(self):
        """Test GET request with large page_size=100 returns up to 100 results."""
        response = self.client.get("/api/experts/?page_size=100")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLessEqual(len(response.data["results"]), 100)

    def test_get_page_beyond_range(self):
        """Test GET request with page_size=25 does not exceed total number of EAs."""
        response = self.client.get("/api/experts/?page_size=25")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 20)

    def test_get_ea_10_to_20_with_page_size_10_page_2(self):
        """Assert that a specific EA is correctly paginated on page 2 when ordered by created_at ascending."""
        # Get the 11th EA when sorted by created_at ascending
        expected_ea = ExpertAdvisor.objects.order_by('created_at')[10]
        # Make the request for page 2 with ordering by created_at
        response = self.client.get("/api/experts/?ordering=created_at&page=2&page_size=10")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Ensure the expected EA is in the results
        returned_ids = [ea["magic_number"] for ea in response.data["results"]]
        self.assertIn(expected_ea.magic_number, returned_ids)

    def test_get_single_ea_by_id(self):
        """Test retrieving a single Expert Advisor by its magic_number returns correct data."""
        ea = ExpertAdvisor.objects.first()
        response = self.client.get(f"/api/experts/{ea.magic_number}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], ea.name)

    def test_search_by_name(self):
        """Test searching by EA name returns expected results."""
        response = self.client.get("/api/experts/?search=EA 1")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(any("EA 1" in ea["name"] for ea in response.data["results"]))

    def test_search_by_description(self):
        """Test searching by EA description returns expected results."""
        response = self.client.get("/api/experts/?search=description 5&ordering=created_at")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(any("description 5" in ea["description"] for ea in response.data["results"]))

    def test_search_by_author(self):
        """Test searching by EA author returns expected results."""
        response = self.client.get("/api/experts/?search=Author 3")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(any("Author 3" in ea["author"] for ea in response.data["results"]))

    def test_order_by_download_count(self):
        """Test ordering Expert Advisors by download count in descending order."""
        response = self.client.get("/api/experts/?ordering=-download_count")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 10)

    def test_order_by_created_at(self):
        """Test ordering Expert Advisors by creation time in ascending order."""
        response = self.client.get("/api/experts/?ordering=created_at")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 10)


    def test_ordering_by_download_count_reflects_actual_counts(self):
        """Test that EAs with more ExpertUser subscriptions appear higher when ordered by download count."""
        user_model = get_user_model()
        ea_with_3 = ExpertAdvisor.objects.get(name="EA 0")
        ea_with_2 = ExpertAdvisor.objects.get(name="EA 1")
        ea_with_1 = ExpertAdvisor.objects.get(name="EA 2")

        # Create users and link them to EAs
        for i in range(3):
            user = user_model.objects.create_user(
                email=f"user{i}@example.com",
                full_name=f"User {i}",
                password="testpass"
            )
            if i < 3:
                ExpertUser.objects.create(user=user, expert=ea_with_3)
            if i < 2:
                ExpertUser.objects.create(user=user, expert=ea_with_2)
            if i < 1:
                ExpertUser.objects.create(user=user, expert=ea_with_1)

        response = self.client.get("/api/experts/?ordering=-download_count")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        ordered_ids = [ea["magic_number"] for ea in response.data["results"][:3]]
        expected_order = [ea_with_3.magic_number, ea_with_2.magic_number, ea_with_1.magic_number]
        self.assertEqual(ordered_ids, expected_order)

    def test_non_programmer_cannot_create_expertadvisor(self):
        """Test that a user with role 'user' cannot create an Expert Advisor (403 Forbidden)."""
        # Register and log in a regular (non-programmer) user
        regular_data = {
            "email": "user@example.com",
            "full_name": "Regular User",
            "password": "userpass123",
            "role": "user"
        }
        self.client.post("/api/register/", regular_data, format='json')
        login_resp = self.client.post(
            "/api/login/",
            {"email": regular_data["email"], "password": regular_data["password"]},
            format='json'
        )
        regular_token = login_resp.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {regular_token}')

        # Attempt to create an EA as a regular user
        ea_data = {
            "name": "Forbidden EA",
            "description": "Should not be allowed",
            "version": "1.0",
            "author": "Malicious",
            "image_url": "https://example.com/forbidden.png",
            "file_url": "https://example.com/forbidden.ex4"
        }
        response = self.client.post("/api/experts/", ea_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

