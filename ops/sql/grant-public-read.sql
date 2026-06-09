-- Kramerius local test helper.
--
-- Imported public objects expose IMG_FULL through the a_read action. Some
-- default local databases only grant a_read through IP criteria, which can
-- leave browser users as "not_logged" with thumbnails but without full IIIF
-- image access. This idempotently grants root a_read to common_users.

begin;

insert into right_entity (
    right_id,
    update_timestamp,
    uuid,
    action,
    rights_crit,
    user_id,
    group_id,
    role,
    fixed_priority
)
select
    nextval('right_id_sequence'),
    now(),
    'uuid:1',
    'a_read',
    null,
    null,
    group_id,
    gname,
    null
from group_entity
where gname = 'common_users'
  and not exists (
      select 1
      from right_entity
      where uuid = 'uuid:1'
        and action = 'a_read'
        and group_id = group_entity.group_id
        and rights_crit is null
  );

commit;

select right_id, uuid, action, group_id, role, rights_crit
from right_entity
where uuid = 'uuid:1'
  and action in ('a_read', 'a_pdf_read')
order by right_id;
