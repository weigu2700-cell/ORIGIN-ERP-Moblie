import 'package:origin_mobile/core/api.dart';
import 'package:origin_mobile/core/chat_mock.dart';
import 'package:origin_mobile/core/chat_store.dart';
import 'package:origin_mobile/core/session.dart';

class MemoryVault implements TokenVault {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class FixtureApi extends ApiClient {
  final requests = <String>[];
  Future<dynamic> Function(
    String path,
    String method,
    Json query,
    dynamic body,
  )?
  handler;
  FixtureApi() : super('https://test.invalid/api');

  @override
  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Json query = const {},
    dynamic body,
    bool auth = true,
  }) async {
    requests.add('$method $path');
    if (handler != null) return handler!(path, method, query, body);
    if (path == '/auth/tenant/context') {
      return {
        'mode': 'single',
        'organization': {'code': 'origin', 'name': '原点制造'},
      };
    }
    if (path == '/master/warehouse') {
      return {
        'records': [
          {'id': '001', 'name': '成品仓库'},
        ],
        'total': 1,
      };
    }
    if (path == '/sys/notification/unread/count') return 5;
    if (path == '/sys/notification') {
      return {
        'records': [
          {
            'id': '1',
            'title': '报工审批结果',
            'content': '报工单 PR-1103-021 已通过审批，可查看后续成品入库单。',
            'businessType': 'PRODUCTION_REPORT_APPROVED',
            'createTime': '2026-11-03 09:28:00',
            'isRead': false,
          },
          {
            'id': '2',
            'title': '生产领料待办',
            'content': '领料单 PL-1103-024 已审批，请核对物料后办理领料。',
            'businessType': 'PRODUCTION_PICKING_READY',
            'createTime': '2026-11-03 09:16:00',
            'isRead': false,
          },
          {
            'id': '3',
            'title': '采购到货通知',
            'content': '采购入库单 PI-1103-006 已审核，待仓库办理上架。',
            'createTime': '2026-11-02 08:35:00',
            'isRead': true,
          },
        ],
        'total': 3,
      };
    }
    if (path.startsWith('/ai/conversation/')) {
      return {'id': '1', 'title': '本周库存预警汇总', 'status': 0};
    }
    if (path.startsWith('/ai/message/')) {
      return [
        {'role': 'user', 'content': '本周有哪些物料库存不足？'},
        {
          'role': 'assistant',
          'content': '共有 **2 种**物料低于安全库存：\n\n- 精密轴承：可用 0.3 件\n- 铝合金外壳：可用 0 件',
        },
      ];
    }
    if (path == '/ai/conversation') {
      return [
        {
          'id': '1',
          'title': '本周库存预警汇总',
          'updateTime': DateTime.now().toString().substring(0, 16),
          'status': 'ACTIVE',
        },
        {
          'id': '2',
          'title': '查询 MO-1103-018 进度',
          'updateTime': DateTime.now().toString().substring(0, 16),
          'status': 'ACTIVE',
        },
      ];
    }
    if (path == '/inv/finish-warehousing') {
      return {
        'records': [
          {
            'id': '11',
            'warehousingNo': 'FG-1103-012',
            'materialName': '伺服驱动器',
            'warehouseName': '成品一号仓',
            'status': 1,
          },
        ],
        'total': 1,
      };
    }
    if (path.startsWith('/inventory/material-stock/')) {
      return {
        'id': '9007199254740993123',
        'materialCode': 'MM356763840412782592',
        'materialName': '精密轴承',
        'warehouseName': '原料仓库',
        'available': 12.5,
        'reserved': 7.5,
        'onHand': 20.0,
      };
    }
    if (path.startsWith('/prd/order/')) {
      return {
        'id': '21',
        'productionOrderNo': 'PO202609210001',
        'materialId': '2',
        'materialName': '伺服驱动器',
        'materialCode': 'MM356774248368443392',
        'warehouseId': '001',
        'warehouseName': '成品一号仓',
        'status': 2,
        'plannedQuantity': 136.0,
        'completedQuantity': 48.0,
        'plannedStartTime': '2026-09-21 08:00:00',
        'plannedEndTime': '2026-09-28 18:00:00',
        'remark': '加急订单，优先排产',
      };
    }
    if (path == '/prd/order') {
      return {
        'records': [
          {
            'id': '21',
            'productionOrderNo': 'PO202609210001',
            'materialName': '伺服驱动器',
            'status': 2,
            'plannedQuantity': 136.0,
            'completedQuantity': 48.0,
            'plannedEndTime': '2026-09-28 18:00:00',
          },
          {
            'id': '22',
            'productionOrderNo': 'PO202609210002',
            'materialName': '铝合金外壳',
            'status': 1,
            'plannedQuantity': 300.0,
            'completedQuantity': 0.0,
            'plannedEndTime': '2026-10-05 18:00:00',
          },
        ],
        'total': 2,
      };
    }
    if (path == '/inventory/material-stock') {
      return {
        'records': [
          {
            'id': '9007199254740993123',
            'materialCode': '000012345678901234567890',
            'materialName': '精密轴承',
            'warehouseName': '原料仓库',
            'available': 12.5,
            'reserved': 7.5,
            'onHand': 20.0,
          },
        ],
        'total': 1,
      };
    }
    return {'records': <Json>[], 'total': 0};
  }
}

Session authenticatedSession(FixtureApi api) => Session(api, MemoryVault())
  ..status = SessionStatus.authenticated
  ..businessAvailable = true
  ..organization = {'code': 'origin', 'name': '原点制造'}
  ..profile = {
    'id': '001',
    'username': 'worker',
    'realName': '生产作业员',
    'roles': [
      {'roleCode': 'ADMIN', 'roleName': '管理员'},
    ],
  };

/// 页面测试使用内存聊天，不连接 WebSocket。
ChatStore testChat(Session session) =>
    ChatStore(session, api: MockChatApi(delay: Duration.zero));
