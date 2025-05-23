from rest_framework import serializers
from .models import User

class RegisterSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField(required=True)
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('id', 'email', 'full_name', 'password', 'role', 'username')

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'email', 'full_name', 'role', "username")
        read_only_fields = ('id',)