import os

# See: https://github.com/GoogleCloudPlatform/python-docs-samples/blob/main/functions/helloworld/main.py#L76
def run(event, context):
    foo = os.environ.get('SUPER_SECRET_VALUE', 'Specified environment variable is not set.')
    print(foo)
    return
