
from rest_framework import serializers
from .models import Trade

class TradeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trade
        fields = [
            'id',
            'expert',
            'user',
            'open_time',
            'close_time',
            'profit',
            'lot_size',
            'ticker'
        ]
    
    def get_fields(self):
        fields = super().get_fields()
        # If we're updating (instance exists), lock open_time
        if self.instance is not None:
            fields['open_time'].read_only = True
        return fields