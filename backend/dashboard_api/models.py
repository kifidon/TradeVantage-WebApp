from django.db import models
from django.conf import settings
from market_api.models import ExpertAdvisor
import uuid

# Create your models here.

class Trade(models.Model):
    """
    Model representing a trade made by an Expert Advisor for a user.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    expert = models.ForeignKey(ExpertAdvisor, on_delete=models.CASCADE, related_name='trades')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='trades')
    open_time = models.DateTimeField()
    close_time = models.DateTimeField(null=True, blank=True)
    profit = models.DecimalField(max_digits=12, decimal_places=2)
    lot_size = models.DecimalField(max_digits=10, decimal_places=2)
    ticker = models.CharField(max_length=10, null=False, blank=False)
    direction = models.CharField(max_length=4, choices=[('BUY', 'Buy'), ('SELL', 'Sell')])
    ticket_number = models.IntegerField()
    
    class Meta:
        db_table = 'trades'
        verbose_name = 'Trade'
        verbose_name_plural = 'Trades'
        ordering = ['-open_time']
        # Ensure a user cannot have two trades with the same ticket number
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'ticket_number'],
                name='unique_user_ticket_number'
            )
        ]

    def __str__(self):
        return f"Trade {self.id} by {self.user.email} on {self.expert.name}"
