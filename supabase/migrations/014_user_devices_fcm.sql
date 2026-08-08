-- FCM device tokens for push notifications (admin broadcasts).

alter table public.user_devices
  add column if not exists fcm_token text;

comment on column public.user_devices.fcm_token is 'Firebase Cloud Messaging registration token for this device; updated on mobile login.';
