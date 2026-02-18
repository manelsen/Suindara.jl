import os
import sys
from django.conf import settings
from django.core.wsgi import get_wsgi_application
from django.http import JsonResponse
from django.urls import path

# Configure Django settings
settings.configure(
    DEBUG=False,
    SECRET_KEY='secret',
    ROOT_URLCONF=__name__,
    ALLOWED_HOSTS=['*'],
    LOGGING={
        'version': 1,
        'disable_existing_loggers': True,
    }
)

def index(request):
    return JsonResponse({"message": "Hello World"})

urlpatterns = [
    path('', index),
]

application = get_wsgi_application()

if __name__ == "__main__":
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)
