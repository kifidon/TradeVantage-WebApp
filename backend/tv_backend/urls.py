# urls.py
from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework.routers import DefaultRouter
from accounts.views import RegisterView, RetrievUserView, SupaBaseLoginView
from market_api.views import ExpertAdvisorViewSet, ExpertUserViewSet, SupabasePrivateUploadView
from dashboard_api.views import TradeViewSet, ExpertUserTradeCheck

router = DefaultRouter()
router.register(r'experts', ExpertAdvisorViewSet, basename='experts')
router.register(r'subscriptions', ExpertUserViewSet, basename='subscriptions')
router.register(r'trade', TradeViewSet, basename='trade')


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/register/', RegisterView.as_view(), name='register'),
    path('api/login/', SupaBaseLoginView.as_view(), name='login'),
    path('api/user/', RetrievUserView.as_view(), name='user_profile'),
    path('api/trade-auth/<int:magic_number>/', ExpertUserTradeCheck.as_view(), name='trade_auth'),
    path('api/', include(router.urls)),
    path('api/files/', SupabasePrivateUploadView.as_view(), name='supabase_upload'),
]
