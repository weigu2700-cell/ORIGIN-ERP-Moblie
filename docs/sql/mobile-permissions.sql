-- 补齐移动端领料、报工、成品入库所需的细分权限，并授予 admin 角色。
-- 权限码与服务端 @PreAuthorize 一致（来自 origin-erp-service/sql/smart-erp/permission_init.sql）。
-- 可重复执行：只新增缺失的权限和授权，不改已有数据。
USE `smart-erp`;
SET NAMES utf8mb4;
START TRANSACTION;

INSERT INTO sys_permission (name, code, type, status, sort, create_time, deleted)
SELECT t.name, t.code, t.type, 1, 0, NOW(), 0
FROM (
  SELECT '列表' AS name, 'inv:finish-warehousing:list' AS code, 1 AS type
  UNION ALL SELECT '详情', 'inv:finish-warehousing:get', 2
  UNION ALL SELECT '新增', 'prd:report:add', 2
  UNION ALL SELECT '审核', 'prd:report:approve', 2
  UNION ALL SELECT '取消', 'prd:report:cancel', 2
  UNION ALL SELECT '详情', 'prd:report:get', 2
  UNION ALL SELECT '列表', 'prd:report:page', 1
  UNION ALL SELECT '驳回', 'prd:report:reject', 2
  UNION ALL SELECT '审核', 'production:picking:approve', 2
  UNION ALL SELECT '确认', 'production:picking:confirm', 2
  UNION ALL SELECT '详情', 'production:picking:get', 2
  UNION ALL SELECT '列表', 'production:picking:list', 1
) t
WHERE NOT EXISTS (SELECT 1 FROM sys_permission p WHERE p.code = t.code);

-- 授予 admin 角色（用户 g 的角色）；已授权的不重复插入。
INSERT INTO sys_role_permission (id, role_id, permission_id)
SELECT UUID_SHORT(), r.id, p.id
FROM sys_role r
JOIN sys_permission p ON p.deleted = 0 AND p.status = 1 AND p.code IN (
  'inv:finish-warehousing:list','inv:finish-warehousing:get',
  'prd:report:add','prd:report:approve','prd:report:cancel','prd:report:get',
  'prd:report:page','prd:report:reject',
  'production:picking:approve','production:picking:confirm',
  'production:picking:get','production:picking:list')
WHERE r.code = 'admin' AND r.deleted = 0 AND r.status = 1
  AND NOT EXISTS (
    SELECT 1 FROM sys_role_permission rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id);

COMMIT;

-- 核对：应返回 12 行
SELECT p.code FROM sys_permission p
JOIN sys_role_permission rp ON rp.permission_id = p.id
JOIN sys_role r ON r.id = rp.role_id AND r.code = 'admin'
WHERE p.code IN (
  'inv:finish-warehousing:list','inv:finish-warehousing:get',
  'prd:report:add','prd:report:approve','prd:report:cancel','prd:report:get',
  'prd:report:page','prd:report:reject',
  'production:picking:approve','production:picking:confirm',
  'production:picking:get','production:picking:list');
