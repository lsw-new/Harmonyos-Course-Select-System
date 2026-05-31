import { AdminPermissionAction } from '../../models/Admin';
import { SessionStorage } from '../storage/SessionStorage';

export class AuthorizationService {
  static isAdminAuthenticated(): boolean {
    const session = SessionStorage.get();
    return session.isAuthenticated() && session.getRole() === 'admin' && session.getAdmin() !== undefined;
  }

  static hasAdminPermission(code: string, action: AdminPermissionAction): boolean {
    const session = SessionStorage.get();
    if (!AuthorizationService.isAdminAuthenticated()) {
      return false;
    }
    const admin = session.getAdmin();
    if (!admin) {
      return false;
    }
    return admin.permissions.some((permission) => {
      return permission.code === code && permission.actions.indexOf(action) >= 0;
    });
  }
}
