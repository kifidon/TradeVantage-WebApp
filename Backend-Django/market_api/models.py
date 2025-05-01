from django.db import models
from django.conf import settings
from django.utils import timezone
from datetime import timedelta

class ExpertAdvisor(models.Model):
    """
    Model representing Expert Advisors (EAs) for trading.
    """
    magic_number = models.AutoField(primary_key=True)
    name = models.CharField(max_length=255)
    description = models.TextField()
    version = models.CharField(max_length=50)
    author = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    image_url = models.URLField(max_length=255, blank=True, null=True)
    file_url = models.URLField(max_length=255, blank=True, null=True)

    class Meta:
        verbose_name = 'Expert Advisor'
        verbose_name_plural = 'Expert Advisors'
        ordering = ['-created_at']
        managed = True
        db_table = 'expert_advisors'

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
    last_paid_at = models.DateTimeField(default=timezone.now)

    def thirty_days_from_now():
        return timezone.now() + timedelta(days=30)

    expires_at = models.DateTimeField(default=thirty_days_from_now)
    
    class Meta:
        verbose_name = 'Expert User'
        verbose_name_plural = 'Expert Users'
        db_table = 'expert_users'
        unique_together = ('user', 'expert')
        managed = True

    def __str__(self):
        return f"{self.user.email} subscribed to {self.expert.name}"
    
    