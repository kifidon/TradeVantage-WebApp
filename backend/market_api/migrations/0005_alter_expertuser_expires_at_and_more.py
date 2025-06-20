# Generated by Django 5.2.1 on 2025-05-26 00:35

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('market_api', '0004_expertuser_account_number'),
    ]

    operations = [
        migrations.AlterField(
            model_name='expertuser',
            name='expires_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='expertuser',
            name='last_paid_at',
            field=models.DateTimeField(blank=True, default=None, null=True),
        ),
    ]
