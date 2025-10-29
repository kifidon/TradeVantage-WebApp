from rest_framework.permissions import BasePermission, SAFE_METHODS
from rest_framework.viewsets import ModelViewSet
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import MethodNotAllowed
from rest_framework import generics
from .filters import TradeFilter
from .models import Trade
from .serializers import TradeSerializer
from market_api.models import ExpertUser
from market_api.serializers import ExpertUserSerializer
from rest_framework.response import Response
from django.utils import timezone
from rest_framework import status
from rest_framework.generics import RetrieveAPIView


# Custom permission: only owner can update/delete, any authenticated user can read
class IsOwnerOrReadOnly(BasePermission):
    """
    Custom permission to only allow owners of a Trade to update or delete it.
    """
    def has_object_permission(self, request, view, obj):
        # Read permissions for any authenticated user
        if request.method in SAFE_METHODS:
            return True
        # Write permissions only for the owner
        return obj.user == request.user

class TradeViewSet(ModelViewSet):
    serializer_class = TradeSerializer
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
    filter_backends = [DjangoFilterBackend]
    filterset_class = TradeFilter

    def get_queryset(self):
        return Trade.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def destroy(self, request, *args, **kwargs):
        """
        Disable deletion of Trade records via API.
        """
        raise MethodNotAllowed(method='DELETE')

class ExpertUserTradeCheck(RetrieveAPIView):
    serializer_class = ExpertUserSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'expert__magic_number'
    lookup_url_kwarg = 'magic_number'

    def get_object(self):
        """
        Retrieve the subscription for the authenticated user, given EA magic number, and creator email.
        The creator_email is used to uniquely identify the EA when multiple EAs have the same magic_number.
        """
        magic = self.kwargs[self.lookup_url_kwarg]
        creator_email = self.request.query_params.get('creator_email', '').strip().lower()
        
        # Build query filter
        filter_kwargs = {
            'user': self.request.user,
            'expert__magic_number': magic
        }
        
        # If creator_email is provided, filter by it to uniquely identify the EA
        if creator_email:
            filter_kwargs['expert__created_by__email'] = creator_email
        
        subscriptions = ExpertUser.objects.filter(**filter_kwargs).order_by('-expires_at', '-subscribed_at')
        
        # Try to get an active subscription first
        active_subscription = subscriptions.filter(expires_at__gt=timezone.now()).first()
        if active_subscription:
            return active_subscription
        
        # If no active subscription, return the most recent one
        # This handles the case where all subscriptions are expired or pending
        subscription = subscriptions.first()
        
        if not subscription:
            from django.core.exceptions import ObjectDoesNotExist
            error_msg = f"No subscription found for magic number {magic}"
            if creator_email:
                error_msg += f" from creator {creator_email}"
            raise ObjectDoesNotExist(error_msg)
        
        return subscription

    def retrieve(self, request, *args, **kwargs):
        """
        Return the subscription if active; otherwise respond with '410 Gone'.
        """
        subscription = self.get_object()
        if timezone.now() >= subscription.expires_at:
            return Response({'detail': 'Subscription expired'}, status=status.HTTP_410_GONE)
        serializer = self.get_serializer(subscription)
        return Response(serializer.data, status=status.HTTP_200_OK)
