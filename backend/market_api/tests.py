from unittest.mock import patch
from rest_framework.test import APITestCase, APIClient
from rest_framework import status

import accounts.authentication
from .models import ExpertAdvisor, ExpertUser
from accounts.models import User
import accounts 
from django.contrib.auth import get_user_model
from datetime import timedelta
from django.utils import timezone
from accounts.views import SupaBaseLoginView
import json
import requests
import os

class ExpertAdvisorTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user_data = {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "testuser@gmail.com",
            "full_name": "Test User",
            "password": "securepassword123",
            "role": "programmer",
            "username": "TestUser",
        }
        cls.test_user = User.objects.create_user(**cls.user_data)
        
        # Create 20 mock ExpertAdvisors
        test_user = User.objects.get(username="TestUser")
        for i in range(20):
            ExpertAdvisor.objects.create(
                name=f"EA {i}",
                description=f"This is description {i}",
                version="1.0",
                author=f"Author {i % 5}",
                created_at=timezone.now() - timedelta(days=i),
                updated_at=timezone.now() - timedelta(days=i),
                image_url=f"https://example.com/image{i}.png",
                file=f"file{i}.ex4",
                magic_number=i * i,
                supported_pairs=["EURUSD", "GBPUSD"],
                timeframes=["M1", "M5"],
                minimum_deposit=100.0,
                price=50.0,
                parameters={"param1": "value1", "param2": "value2"},
                created_by=test_user,
            )
            
    
    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_create_valid_expert_advisor(self, mock_authenticate):
        """Test creating an Expert Advisor with valid data should succeed (201 Created)."""
        mock_authenticate.return_value = (self.test_user, None)
        data = {
            "name": "Valid EA",
            "description": "A valid EA",
            "version": "1.0",
            "author": "Test Author",
            "image_url": "https://example.com/image.png",
            "file": "https://example.com/ea.ex4",
            "magic_number": 123456,
            "supported_pairs": ["EURUSD", "GBPUSD"],
            "timeframes": ["M5", "H1"],
            "minimum_deposit": 100.0,
            "price": 99.99,
            "instructions": "https://example.com/ea.pdf",
            "parameters": {
                "lot_size": "0.1",
                "risk": "2"
            }
        }
        response = self.client.post("/api/experts/", data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_create_invalid_image_url(self, mock_authenticate):
        """Test creating an Expert Advisor with an invalid image_url should fail (400 Bad Request)."""
        mock_authenticate.return_value = (self.test_user, None)
        data = {
            "name": "Invalid Image",
            "description": "Not a valid EA",
            "version": "1.0",
            "author": "Test Author",
            "image_url": "not-an-image-url",
            "file": "https://example.com/ea.ex4",
            "magic_number": 123456,
            "supported_pairs": ["EURUSD", "GBPUSD"],
            "timeframes": ["M5", "H1"],
            "minimum_deposit": 100.0,
            "price": 99.99,
            "instructions": "https://example.com/ea.pdf",
            "parameters": {
                "lot_size": "0.1",
                "risk": "2"
            }
        }
        response = self.client.post("/api/experts/", data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_create_invalid_file_url(self, mock_authenticate):
        """Test creating an Expert Advisor with an invalid file should fail (400 Bad Request)."""
        mock_authenticate.return_value = (self.test_user, None)
        data = {
            "name": "Invalid File",
            "description": "Not a valid EA",
            "version": "1.0",
            "author": "Test Author",
            "image_url": "not-an-image-url",
            "file": "not-a-url",
            "magic_number": 123456,
            "supported_pairs": ["EURUSD", "GBPUSD"],
            "timeframes": ["M5", "H1"],
            "minimum_deposit": 100.0,
            "price": 99.99,
            "instructions": "https://example.com/ea.pdf",
            "parameters": {
                "lot_size": "0.1",
                "risk": "2"
            }
        }
        response = self.client.post("/api/experts/", data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_get_default_page(self, mock_authenticate):
        """Test default GET request returns first 10 EAs due to default page size."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 10)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_get_custom_page_size_20(self, mock_authenticate):
        """Test GET request with page_size=20 returns exactly 20 results."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?page_size=20")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 20)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_get_page_size_100(self, mock_authenticate):
        """Test GET request with large page_size=100 returns up to 100 results."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?page_size=100")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLessEqual(len(response.data["results"]), 100)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_get_page_beyond_range(self, mock_authenticate):
        """Test GET request with page_size=25 does not exceed total number of EAs."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?page_size=25")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 20)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_get_ea_10_to_20_with_page_size_10_page_2(self, mock_authenticate):
        """Assert that a specific EA is correctly paginated on page 2 when ordered by created_at ascending."""
        mock_authenticate.return_value = (self.test_user, None)
        # Get the 11th EA when sorted by created_at ascending
        expected_ea = ExpertAdvisor.objects.order_by('created_at')[10]
        # Make the request for page 2 with ordering by created_at
        response = self.client.get("/api/experts/?ordering=created_at&page=2&page_size=10")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Ensure the expected EA is in the results
        returned_ids = [ea["magic_number"] for ea in response.data["results"]]
        self.assertIn(expected_ea.magic_number, returned_ids)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_get_single_ea_by_id(self, mock_authenticate):
        """Test retrieving a single Expert Advisor by its magic_number returns correct data."""
        mock_authenticate.return_value = (self.test_user, None)
        ea = ExpertAdvisor.objects.first()
        response = self.client.get(f"/api/experts/{ea.id}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], ea.name)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_search_by_name(self, mock_authenticate):
        """Test searching by EA name returns expected results."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?search=EA 1")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(any("EA 1" in ea["name"] for ea in response.data["results"]))

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_search_by_description(self, mock_authenticate):
        """Test searching by EA description returns expected results."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?search=description 5&ordering=created_at")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(any("description 5" in ea["description"] for ea in response.data["results"]))

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_search_by_author(self, mock_authenticate):
        """Test searching by EA author returns expected results."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?search=Author 3")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(any("Author 3" in ea["author"] for ea in response.data["results"]))

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_order_by_download_count(self, mock_authenticate):
        """Test ordering Expert Advisors by download count in descending order."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?ordering=-download_count")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 10)

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_order_by_created_at(self, mock_authenticate):
        """Test ordering Expert Advisors by creation time in ascending order."""
        mock_authenticate.return_value = (self.test_user, None)
        response = self.client.get("/api/experts/?ordering=created_at")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 10)


    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_ordering_by_download_count_reflects_actual_counts(self, mock_authenticate):
        """Test that EAs with more ExpertUser subscriptions appear higher when ordered by download count."""
        mock_authenticate.return_value = (self.test_user, None)
        user_model = get_user_model()
        ea_with_3 = ExpertAdvisor.objects.get(name="EA 0")
        ea_with_2 = ExpertAdvisor.objects.get(name="EA 1")
        ea_with_1 = ExpertAdvisor.objects.get(name="EA 2")

        # Create users and link them to EAs
        for i in range(3):
            user = user_model.objects.create_user(
                username=f"user{i}@example.com",
                full_name=f"User {i}",
                password="testpass",
                email=f"user{i}",
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

    @patch("accounts.authentication.SupabaseJWTAuthentication.authenticate")
    def test_non_programmer_cannot_create_expertadvisor(self, mock_authenticate):
        """Test that a user with role 'user' cannot create an Expert Advisor (403 Forbidden)."""
        # Register and log in a regular (non-programmer) user
        regular_data = {
            "id": "123e4567-e89b-12d3-a456-426614174002",
            "email": "user@example.com",
            "username": "RegularUser",
            "full_name": "Regular User",
            "password": "userpass123",
            "role": "user",
        }
        mockUser = User.objects.create_user(**regular_data)
        mock_authenticate.return_value = (mockUser, None)
        
        # Attempt to create an EA as a regular user
        ea_data = {
            "name": "Forbidden EA",
            "description": "Should not be allowed",
            "version": "1.0",
            "author": "Malicious",
            "image_url": "https://example.com/forbidden.png",
            "file": "forbidden.ex4"
        }
        response = self.client.post("/api/experts/", ea_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
