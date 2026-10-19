"""Validate public update settings and signing identity before touching output."""
import base64, re
from urllib.parse import urlsplit

def https_url(value):
    url = urlsplit(value)
    if (url.scheme != 'https' or not url.hostname or url.username or url.password
            or url.fragment or url.hostname in ('localhost', 'example.com')
            or url.hostname.endswith(('.invalid', '.example'))):
        raise ValueError('A real HTTPS URL without credentials or fragment is required')
    return value

def update_config(config):
    if not config: return {}
    https_url(config['feed_url'])
    key = base64.b64decode(config['public_ed_key'], validate=True)
    if len(key) != 32: raise ValueError('Ed25519 public key must contain 32 bytes')
    return {'SUFeedURL': config['feed_url'], 'SUPublicEDKey': config['public_ed_key'],
            'SUEnableAutomaticChecks': True, 'SUAutomaticallyUpdate': False,
            'SUVerifyUpdateBeforeExtraction': True}

def developer_id(identity, listing):
    for fingerprint, name in re.findall(r'([0-9A-F]{40}) "([^"]+)"', listing):
        if identity in (fingerprint, name) and name.startswith('Developer ID Application:'):
            return fingerprint
    raise ValueError('A valid Developer ID Application identity with its private key is required')
