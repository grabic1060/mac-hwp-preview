import unittest
from release_config import update_config, developer_id
class ReleaseConfigTests(unittest.TestCase):
    def test_valid_and_unconfigured(self):
        self.assertEqual(update_config({}), {})
        c = update_config({'feed_url':'https://updates.hwp-preview.org/appcast.xml','public_ed_key':'m2FtgM4lOJUKfyZeRQiNxKEMxEIWsoXmVMst1WjXwUg='})
        self.assertTrue(c['SUVerifyUpdateBeforeExtraction'])
        self.assertFalse(c['SUAutomaticallyUpdate'])
    def test_invalid_feed(self):
        for url in ['http://example.org/feed','file:///tmp/feed','https://user:secret@host/feed','https://example.com/feed','https://localhost/feed']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                update_config({'feed_url':url,'public_ed_key':'m2FtgM4lOJUKfyZeRQiNxKEMxEIWsoXmVMst1WjXwUg='})
    def test_invalid_key(self):
        for key in ['', '!', 'YQ==']:
            with self.assertRaises(ValueError): update_config({'feed_url':'https://updates.hwp-preview.org/feed','public_ed_key':key})
    def test_development_identity_cannot_release(self):
        fingerprint = 'A'*40
        with self.assertRaises(ValueError): developer_id(fingerprint, f'1) {fingerprint} "Apple Development: Example"')
        self.assertEqual(developer_id(fingerprint, f'1) {fingerprint} "Developer ID Application: Example"'), fingerprint)
if __name__ == '__main__': unittest.main()
