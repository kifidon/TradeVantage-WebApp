# frontend_api/filters.py
from django_filters import rest_framework as filters
from .models import ExpertAdvisor

class ExpertAdvisorFilter(filters.FilterSet):
    title = filters.CharFilter(lookup_expr='icontains')
    created_at = filters.DateFromToRangeFilter()

    class Meta:
        model = ExpertAdvisor
        fields = ['title', 'author', 'version', 'created_at', 'created_by']
        