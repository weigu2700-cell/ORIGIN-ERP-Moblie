export interface UserRole {
  roleName?: string;
  roleCode?: string;
}

export interface CurrentUser {
  id: number;
  username: string;
  realName?: string;
  phone?: string;
  deptName?: string;
  roles: UserRole[];
}

export interface Permission {
  id: number;
  name: string;
  code: string;
  status?: string | number;
}
