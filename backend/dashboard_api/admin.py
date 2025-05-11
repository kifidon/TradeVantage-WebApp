from django.contrib import admin

from .models import Trade

# Register your models here.

@admin.register(Trade)
class TradeAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'expert', 'open_time', 'close_time', 'profit', 'lot_size')
    search_fields = ('user__email', 'expert__name')
    list_filter = ('open_time', 'close_time')
