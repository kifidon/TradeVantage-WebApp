from rest_framework import serializers
from .models import ExpertAdvisor, ExpertUser

class ExpertAdvisorSerializer(serializers.ModelSerializer):
    created_by = serializers.HiddenField(default=serializers.CurrentUserDefault())
    created_by_id = serializers.SerializerMethodField()
    
    def get_created_by_id(self, obj):
        return obj.created_by.id if obj.created_by else None
    
    class Meta:
        model = ExpertAdvisor
        fields = (
            'id',
            'created_by',
            'magic_number',
            'name',
            'description',
            'version',
            'author',
            'created_at',
            'updated_at',
            'supported_pairs',
            'timeframes',
            'minimum_deposit',
            'price',
            'instructions',
            'image_url',
            'file',
            'parameters',
            'created_by_id',
        )
        read_only_fields = [ 'created_at']
        
    def create(self, validated_data):
        return ExpertAdvisor.objects.create(**validated_data)
    
class ExpertUserSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())
    is_active = serializers.ReadOnlyField()
    expert = ExpertAdvisorSerializer(read_only=True)
    expert_id = serializers.PrimaryKeyRelatedField(
        queryset=ExpertAdvisor.objects.all(),
        source='expert',
        write_only=True
    ) 
    user_name = serializers.SerializerMethodField()
    user_email = serializers.SerializerMethodField()

    def get_user_name(self, obj):
        return obj.user.full_name

    def get_user_email(self, obj):
        return obj.user.email

    class Meta:
        model = ExpertUser
        fields = [
            'id', 'user', 'expert', 'expert_id',
            'subscribed_at', 'last_paid_at', 'expires_at',
            'is_active', 'account_number', 'user_name', 'user_email'
        ]
        read_only_fields = ['id', 'user', 'subscribed_at', 'expires_at', 'is_active', 'last_paid_at']