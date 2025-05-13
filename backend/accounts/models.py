# accounts/models.py
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
import uuid


class CustomUserManager(BaseUserManager):
    def create_user(self, email, full_name, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(email=email, full_name=full_name, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, full_name=None, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        if not full_name:
            full_name = 'Admin'

        return self.create_user(email, full_name, password, **extra_fields)

class User(AbstractUser):
    USER = 'user'
    PROGRAMMER = 'programmer'
    ROLE_CHOICES = [
        (USER, 'User'),
        (PROGRAMMER, 'Programmer'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    full_name = models.CharField(max_length=255)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=USER)

    objects = CustomUserManager()

    class Meta:
        db_table = 'auth_user'
        ordering = ['-date_joined']

class SupabaseUser(models.Model):
    id = models.UUIDField(primary_key=True)
    email = models.EmailField()
    role = models.CharField(max_length=50, null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'auth.users'