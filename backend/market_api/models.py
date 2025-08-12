from django.db import models
from tv_backend import settings
from django.utils import timezone
from datetime import timedelta
import uuid, os

class ExpertAdvisor(models.Model):
    """
    Model representing Expert Advisors (EAs) for trading.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    magic_number = models.IntegerField(null=False, blank=False)
    name = models.CharField(max_length=255)
    description = models.TextField()
    version = models.CharField(max_length=50)
    author = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    supported_pairs = models.JSONField(default=list, blank=True)
    timeframes = models.JSONField(default=list, blank=True)
    minimum_deposit = models.DecimalField(max_digits=10, decimal_places=2, null=False, blank=False, default=0)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=100)
    instructions = models.URLField(max_length=255, blank=True, null=True)
    image_url = models.URLField(max_length=255, blank=True, null=True)
    file = models.CharField(max_length=255, blank=True, null=True)
    parameters = models.JSONField(default=dict, blank=True)
    stripe_price_id = models.CharField(max_length=255, blank=True, null=True, help_text="Stripe price ID for this expert advisor")
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='expert_advisor_creator', 
        default=os.getenv("SUPERURUSER")
    )

    
    class Meta:
        verbose_name = 'Expert Advisor'
        verbose_name_plural = 'Expert Advisors'
        ordering = ['-created_at']
        managed = True
        db_table = 'expert_advisors'
        unique_together = (
            ('magic_number', 'created_by'),
            ('name', 'created_by'),
        )

    def __str__(self):
        return self.name

class ExpertUser(models.Model):
    """
    Model representing the relationship between a user and an expert advisor (i.e., downloads/subscriptions).
    """
    id = models.AutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='expert_subscriptions'
    )
    expert = models.ForeignKey(
        ExpertAdvisor,
        on_delete=models.CASCADE,
        related_name='downloads'
    )
    subscribed_at = models.DateTimeField(auto_now_add=True)
    last_paid_at = models.DateTimeField(default=None, blank=True, null=True)
    account_number = models.CharField(max_length=50, blank=True, null=True)
    stripe_subscription_id = models.CharField(max_length=255, blank=True, null=True, help_text="Stripe subscription ID for this user's subscription to this expert advisor")
    expires_at = models.DateTimeField(blank=True, null=True)
    state = models.CharField(max_length=50, blank=True, null=True)
    
    def thirty_days_from_now(self):
        return timezone.now() + timedelta(days=30)
    
    def save(self, *args, **kwargs):
        if self.last_paid_at:
            self.expires_at = self.last_paid_at + timedelta(days=30)
        super().save(*args, **kwargs)

    @property
    def is_active(self):
        if not self.expires_at:
            return "Processing"
        return "Active" if timezone.now() <= self.expires_at else "Expired"
    
    class Meta:
        verbose_name = 'Expert User'
        verbose_name_plural = 'Expert Users'
        db_table = 'expert_users'
        unique_together = ('user', 'expert')
        managed = True

    def __str__(self):
        return f"{self.user.email} subscribed to {self.expert.name}"