from django.contrib import admin
from .models import ExpertAdvisor, ExpertUser


# Register your models here.

@admin.register(ExpertAdvisor)
class ExpertAdvisorAdmin(admin.ModelAdmin):
    list_display = ('magic_number', 'name', 'version', 'author', 'created_at')
    search_fields = ('name', 'author')
    list_filter = ('author',)

@admin.register(ExpertUser)
class ExpertUserAdmin(admin.ModelAdmin):
    list_display = ('user', 'expert', 'subscribed_at', 'last_paid_at', 'expires_at')
    search_fields = ('user__email', 'expert__name')
    list_filter = ('subscribed_at',)
