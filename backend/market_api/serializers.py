from rest_framework import serializers
from .models import ExpertAdvisor, ExpertUser
import stripe
from django.conf import settings

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
            'stripe_price_id',
        )
        read_only_fields = [ 'created_at']
        
    def create(self, validated_data):
        # Set Stripe API key
        stripe.api_key = settings.STRIPE_SECRET_KEY
        
        try:
            # Create Stripe product
            product = stripe.Product.create(
                name=validated_data['name'],
                description=validated_data['description'],
                metadata={
                    'magic_number': str(validated_data['magic_number']),
                    'author': validated_data['author'],
                    'version': validated_data['version']
                }
            )
            
            # Create Stripe price (subscription)
            price = stripe.Price.create(
                product=product.id,
                unit_amount=int(float(validated_data['price']) * 100),  # Convert to cents
                currency='usd',
                recurring={'interval': 'month'},
                metadata={
                    'magic_number': str(validated_data['magic_number']),
                    'expert_type': 'subscription'
                }
            )
            
            # Add the stripe_price_id to validated_data
            validated_data['stripe_price_id'] = price.id
            
        except Exception as e:
            # If Stripe creation fails, still create the expert advisor but log the error
            print(f"Failed to create Stripe product/price: {e}")
            validated_data['stripe_price_id'] = None
        
        return ExpertAdvisor.objects.create(**validated_data)
    
    def update(self, instance, validated_data):
        # Set Stripe API key
        stripe.api_key = settings.STRIPE_SECRET_KEY
        
        # Check if price has changed
        if 'price' in validated_data and validated_data['price'] != instance.price:
            try:
                # If there's an existing Stripe price, create a new one (Stripe prices are immutable)
                if instance.stripe_price_id:
                    # Create new price with updated amount
                    price = stripe.Price.create(
                        product=stripe.Price.retrieve(instance.stripe_price_id).product,
                        unit_amount=int(float(validated_data['price']) * 100),  # Convert to cents
                        currency='usd',
                        recurring={'interval': 'month'},
                        metadata={
                            'magic_number': str(instance.magic_number),
                            'expert_type': 'subscription'
                        }
                    )
                    validated_data['stripe_price_id'] = price.id
                else:
                    # Create new product and price if none exists
                    product = stripe.Product.create(
                        name=validated_data.get('name', instance.name),
                        description=validated_data.get('description', instance.description),
                        metadata={
                            'magic_number': str(instance.magic_number),
                            'author': validated_data.get('author', instance.author),
                            'version': validated_data.get('version', instance.version)
                        }
                    )
                    
                    price = stripe.Price.create(
                        product=product.id,
                        unit_amount=int(float(validated_data['price']) * 100),
                        currency='usd',
                        recurring={'interval': 'month'},
                        metadata={
                            'magic_number': str(instance.magic_number),
                            'expert_type': 'subscription'
                        }
                    )
                    validated_data['stripe_price_id'] = price.id
                    
            except Exception as e:
                print(f"Failed to update Stripe price: {e}")
                # Don't update stripe_price_id if Stripe update fails
        
        return super().update(instance, validated_data)
    
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
            'is_active', 'account_number', 'user_name', 'user_email',
            'stripe_subscription_id', 'state'
        ]
        read_only_fields = ['id', 'user', 'subscribed_at', 'expires_at', 'is_active', 'last_paid_at', 'state']