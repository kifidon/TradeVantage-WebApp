# dashboard_api/filters.py
from django_filters import rest_framework as filters
from .models import Trade

class TradeFilter(filters.FilterSet):
    open_time = filters.DateFromToRangeFilter()
    close_time = filters.DateFromToRangeFilter()
    profit = filters.RangeFilter()
    lot_size = filters.RangeFilter()

    class Meta:
        model = Trade
        fields = ['expert', 'open_time', 'close_time', 'profit', 'lot_size']