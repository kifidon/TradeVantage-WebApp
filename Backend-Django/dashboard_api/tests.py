from rest_framework.test import APITestCase
from rest_framework import status
from django.utils import timezone
from datetime import timedelta
from accounts.models import User
from market_api.models import ExpertAdvisor, ExpertUser
from dashboard_api.models import Trade

class TradeViewSetTests(APITestCase):
    def setUp(self):
        # Create two users
        self.user1 = User.objects.create_user(
            email='user1@example.com', full_name='User One',
            password='pass1', role='user'
        )
        self.user2 = User.objects.create_user(
            email='user2@example.com', full_name='User Two',
            password='pass2', role='user'
        )

        # Authenticate as user1
        login = self.client.post(
            '/api/login/',
            {'email': 'user1@example.com', 'password': 'pass1'},
            format='json'
        )
        self.token1 = login.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.token1}')

        # Create 4 Expert Advisors
        now = timezone.now()
        self.ea1 = ExpertAdvisor.objects.create(
            name='EA1', description='Desc1', version='1.0',
            author='Author1'
        )
        self.ea2 = ExpertAdvisor.objects.create(
            name='EA2', description='Desc2', version='1.0',
            author='Author2'
        )
        self.ea3 = ExpertAdvisor.objects.create(
            name='EA3', description='Desc3', version='1.0',
            author='Author3'
        )
        self.ea4 = ExpertAdvisor.objects.create(
            name='EA4', description='Desc4', version='1.0',
            author='Author4'
        )

        # Subscriptions for user1: ea1 & ea3 active, ea2 expired; ea4 no subscription
        ExpertUser.objects.create(
            user=self.user1, expert=self.ea1,
            subscribed_at=now - timedelta(days=10),
            last_paid_at=now - timedelta(days=5),
            expires_at=now + timedelta(days=25)
        )
        ExpertUser.objects.create(
            user=self.user1, expert=self.ea3,
            subscribed_at=now - timedelta(days=2),
            last_paid_at=now - timedelta(days=1),
            expires_at=now + timedelta(days=29)
        )
        ExpertUser.objects.create(
            user=self.user1, expert=self.ea2,
            subscribed_at=now - timedelta(days=400),
            last_paid_at=now - timedelta(days=400),
            expires_at=now - timedelta(days=365)
        )

        # Create 10 trades for user1 on ea1
        for i in range(5):
            Trade.objects.create(
                user=self.user1, expert=self.ea1,
                open_time=now - timedelta(hours=i),
                profit=10.0 * i,
                lot_size=1.0
            )
        for i in range(5,10):
            Trade.objects.create(
                user=self.user1, expert=self.ea3,
                open_time=now - timedelta(hours=i),
                profit=10.0 * i,
                lot_size=1.0
            )

    def test_create_trade(self):
        """Test creating a new trade for an active subscription succeeds."""
        now = timezone.now()
        data = {
            'expert': self.ea1.magic_number,
            'open_time': timezone.now(),
            'profit': '123.45',
            'lot_size': '2.50'
        }
        response = self.client.post('/api/trade/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Trade.objects.filter(user=self.user1, expert=self.ea1).exists())

    def test_update_trade_profit(self):
        """Test updating only profit of an existing trade succeeds."""
        trade = Trade.objects.first()
        response = self.client.patch(
            f'/api/trade/{trade.id}/',
            {'profit': '999.99'},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        trade.refresh_from_db()
        self.assertEqual(str(trade.profit), '999.99')

    def test_cannot_update_lot_size(self):
        """Test that updating lot_size on a trade is not allowed."""
        trade = Trade.objects.first()
        old_lot = trade.lot_size
        response = self.client.patch(
            f'/api/trade/{trade.id}/',
            {'lot_size': '5.00'},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        trade.refresh_from_db()
        self.assertEqual(trade.lot_size, old_lot)
        # Verify via GET that the lot_size remains unchanged in the API response
        get_resp = self.client.get(f'/api/trade/{trade.id}/', format='json')
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(str(old_lot), get_resp.data['lot_size'])

    def test_delete_trade_not_allowed(self):
        """Test that DELETE on a trade returns 405 Method Not Allowed."""
        trade = Trade.objects.first()
        response = self.client.delete(f'/api/trade/{trade.id}/')
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    def test_list_trades_for_user(self):
        """Test listing trades returns 10 records for user1."""
        response = self.client.get('/api/trade/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 10)

    def test_list_trades_for_user2_empty(self):
        """Test user2 (no trades) receives an empty list."""
        # Authenticate as user2
        login2 = self.client.post(
            '/api/login/',
            {'email': 'user2@example.com', 'password': 'pass2'},
            format='json'
        )
        token2 = login2.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token2}')
        response = self.client.get('/api/trade/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_retrieve_other_user_trade_forbidden(self):
        """Test that accessing another user's trade returns 404."""
        # Trade belongs to user1; user2 should not see it
        trade = Trade.objects.first()
        login2 = self.client.post(
            '/api/login/',
            {'email': 'user2@example.com', 'password': 'pass2'},
            format='json'
        )
        token2 = login2.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token2}')
        response = self.client.get(f'/api/trade/{trade.id}/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_filter_trades_by_unsubscribed_ea(self):
        """Test filtering trades by EA with no subscription returns empty."""
        response = self.client.get(f'/api/trade/?expert={self.ea4.magic_number}')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_subscription_check_active_and_expired(self):
        """Test checking subscription expiration returns 200 for active and 410 for expired."""
        # Active subscription EA1
        resp_active = self.client.get(f'/api/trade-auth/{self.ea1.magic_number}/')
        self.assertEqual(resp_active.status_code, status.HTTP_200_OK)
        # Expired subscription EA2
        resp_expired = self.client.get(f'/api/trade-auth/{self.ea2.magic_number}/')
        self.assertEqual(resp_expired.status_code, status.HTTP_410_GONE)
