from rest_framework import serializers
from .models import ExpertAdvisor, ExpertUser

class ExpertAdvisorSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExpertAdvisor
        fields = ('magic_number', 'name', 'description', 'version', 'author', 'created_at', 'updated_at', 'image_url', 'file_url',)
        read_only_fields = [ 'created_at']
        
    def create(self, validated_data):
        return ExpertAdvisor.objects.create(**validated_data)
    
class ExpertUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExpertUser
        fields = ['id', 'user', 'expert', 'subscribed_at', 'last_paid_at', 'expires_at']
        read_only_fields = ['subscribed_at']
        
    def create(self, validated_data):
        return ExpertUser.objects.create(**validated_data)
