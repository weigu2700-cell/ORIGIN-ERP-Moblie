import type { EntityId } from '@/types/common/entity';

export interface UserRole {
  roleName?: string;
  roleCode?: string;
}

export interface CurrentUser {
  id: EntityId;
  username: string;
  realName?: string;
  phone?: string;
  deptName?: string;
  roles: UserRole[];
}

export interface Permission {
  id: EntityId;
  name: string;
  code: string;
  parentId?: EntityId;
  parentName?: string;
  sort?: number;
  status?: string | number;
  remark?: string;
}
