import 'package:comand_ia/features/orders/domain/entities/customer_order.dart';
import 'package:comand_ia/features/orders/domain/entities/dining_table.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_category.dart';
import 'package:comand_ia/features/orders/domain/entities/menu_item.dart';
import 'package:comand_ia/features/orders/domain/entities/order_item.dart';
import 'package:comand_ia/features/orders/domain/entities/pending_op.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MenuCategory', () {
    const category = MenuCategory(
      id: 'cat-1',
      venueId: 'venue-1',
      name: 'Bebidas',
    );

    test('props incluye todos los campos', () {
      expect(category.props, [
        'cat-1',
        'venue-1',
        'Bebidas',
        0, // sortOrder
        true, // active
        null, // updatedAt
      ]);
    });

    test('igualdad por valor (Equatable)', () {
      const same = MenuCategory(
        id: 'cat-1',
        venueId: 'venue-1',
        name: 'Bebidas',
      );
      expect(category, equals(same));
    });

    test('categorías distintas no son iguales', () {
      const other = MenuCategory(
        id: 'cat-2',
        venueId: 'venue-1',
        name: 'Postres',
      );
      expect(category, isNot(equals(other)));
    });
  });

  group('MenuItem', () {
    const item = MenuItem(
      id: 'item-1',
      venueId: 'venue-1',
      categoryId: 'cat-1',
      name: 'Coca-Cola',
      description: 'Bebida refrescante',
      priceCents: 1500,
    );

    test('priceCents es int (nunca float)', () {
      expect(item.priceCents, isA<int>());
      expect(item.priceCents, 1500);
    });

    test('props incluye todos los campos', () {
      expect(item.props, [
        'item-1',
        'venue-1',
        'cat-1',
        'Coca-Cola',
        'Bebida refrescante',
        1500,
        true, // active
        null, // imageUrl
        0, // sortOrder
        null, // updatedAt
      ]);
    });

    test('igualdad por valor', () {
      const same = MenuItem(
        id: 'item-1',
        venueId: 'venue-1',
        categoryId: 'cat-1',
        name: 'Coca-Cola',
        description: 'Bebida refrescante',
        priceCents: 1500,
      );
      expect(item, equals(same));
    });
  });

  group('DiningTable', () {
    const table = DiningTable(
      id: 'table-1',
      venueId: 'venue-1',
      label: 'Mesa 1',
    );

    test('capacidad por defecto es 4', () {
      expect(table.capacity, 4);
    });

    test('props incluye todos los campos', () {
      expect(table.props, ['table-1', 'venue-1', 'Mesa 1', 4, true, 0, null]);
    });

    test('igualdad por valor', () {
      const same = DiningTable(
        id: 'table-1',
        venueId: 'venue-1',
        label: 'Mesa 1',
      );
      expect(table, equals(same));
    });
  });

  group('OrderStatus conversión enum<->text', () {
    test('fromDb convierte todos los valores válidos', () {
      expect(OrderStatus.fromDb('open'), OrderStatus.open);
      expect(OrderStatus.fromDb('sent'), OrderStatus.sent);
      expect(OrderStatus.fromDb('preparing'), OrderStatus.preparing);
      expect(OrderStatus.fromDb('ready'), OrderStatus.ready);
      expect(OrderStatus.fromDb('closed'), OrderStatus.closed);
      expect(OrderStatus.fromDb('cancelled'), OrderStatus.cancelled);
    });

    test('toDb retorna el text correcto', () {
      expect(OrderStatus.open.toDb(), 'open');
      expect(OrderStatus.sent.toDb(), 'sent');
      expect(OrderStatus.preparing.toDb(), 'preparing');
      expect(OrderStatus.ready.toDb(), 'ready');
      expect(OrderStatus.closed.toDb(), 'closed');
      expect(OrderStatus.cancelled.toDb(), 'cancelled');
    });

    test('fromDb lanza ArgumentError con valor desconocido', () {
      expect(() => OrderStatus.fromDb('invalid_status'), throwsArgumentError);
    });
  });

  group('PaymentMethod conversión enum<->text', () {
    test('fromDb convierte todos los valores válidos', () {
      expect(PaymentMethod.fromDb('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromDb('card'), PaymentMethod.card);
      expect(PaymentMethod.fromDb('transfer'), PaymentMethod.transfer);
      expect(PaymentMethod.fromDb('other'), PaymentMethod.other);
    });

    test('toDb retorna el text correcto', () {
      expect(PaymentMethod.cash.toDb(), 'cash');
      expect(PaymentMethod.card.toDb(), 'card');
      expect(PaymentMethod.transfer.toDb(), 'transfer');
      expect(PaymentMethod.other.toDb(), 'other');
    });

    test('fromDb lanza ArgumentError con valor desconocido', () {
      expect(() => PaymentMethod.fromDb('bitcoin'), throwsArgumentError);
    });
  });

  group('OrderItemStatus conversión enum<->text', () {
    test('fromDb convierte todos los valores válidos', () {
      expect(OrderItemStatus.fromDb('sent'), OrderItemStatus.sent);
      expect(OrderItemStatus.fromDb('preparing'), OrderItemStatus.preparing);
      expect(OrderItemStatus.fromDb('ready'), OrderItemStatus.ready);
      expect(OrderItemStatus.fromDb('cancelled'), OrderItemStatus.cancelled);
    });

    test('toDb retorna el text correcto', () {
      expect(OrderItemStatus.sent.toDb(), 'sent');
      expect(OrderItemStatus.preparing.toDb(), 'preparing');
      expect(OrderItemStatus.ready.toDb(), 'ready');
      expect(OrderItemStatus.cancelled.toDb(), 'cancelled');
    });

    test('fromDb lanza ArgumentError con valor desconocido', () {
      expect(() => OrderItemStatus.fromDb('unknown'), throwsArgumentError);
    });
  });

  group('PendingOpType conversión enum<->text', () {
    test('fromDb convierte todos los valores válidos', () {
      expect(PendingOpType.fromDb('create_order'), PendingOpType.createOrder);
      expect(
        PendingOpType.fromDb('update_order_item'),
        PendingOpType.updateOrderItem,
      );
      expect(PendingOpType.fromDb('close_order'), PendingOpType.closeOrder);
      expect(
        PendingOpType.fromDb('update_order_status'),
        PendingOpType.updateOrderStatus,
      );
    });

    test('toDb retorna el text snake_case correcto', () {
      expect(PendingOpType.createOrder.toDb(), 'create_order');
      expect(PendingOpType.updateOrderItem.toDb(), 'update_order_item');
      expect(PendingOpType.closeOrder.toDb(), 'close_order');
      expect(PendingOpType.updateOrderStatus.toDb(), 'update_order_status');
    });

    test('fromDb lanza ArgumentError con valor desconocido', () {
      expect(
        () => PendingOpType.fromDb('delete_everything'),
        throwsArgumentError,
      );
    });
  });

  group('CustomerOrder', () {
    final now = DateTime(2026, 5, 28, 10);
    final order = CustomerOrder(
      id: 'order-1',
      venueId: 'venue-1',
      diningTableId: 'table-1',
      status: OrderStatus.open,
      openedAt: now,
      totalCents: 0,
    );

    test('totalCents es int', () {
      expect(order.totalCents, isA<int>());
    });

    test('props incluye todos los campos', () {
      expect(order.props, [
        'order-1',
        'venue-1',
        'table-1',
        OrderStatus.open,
        null, // openedBy
        now,
        null, // closedAt
        0, // totalCents
        null, // paymentMethod
        null, // notes
        null, // updatedAt
      ]);
    });

    test('igualdad por valor', () {
      final same = CustomerOrder(
        id: 'order-1',
        venueId: 'venue-1',
        diningTableId: 'table-1',
        status: OrderStatus.open,
        openedAt: now,
        totalCents: 0,
      );
      expect(order, equals(same));
    });
  });

  group('OrderItem', () {
    final item = OrderItem(
      id: 'oi-1',
      venueId: 'venue-1',
      orderId: 'order-1',
      menuItemId: 'item-1',
      nameSnapshot: 'Coca-Cola',
      priceCentsSnapshot: 1500,
      quantity: 2,
      status: OrderItemStatus.sent,
    );

    test('priceCentsSnapshot es int', () {
      expect(item.priceCentsSnapshot, isA<int>());
    });

    test('props incluye todos los campos incluyendo snapshots', () {
      expect(item.props, [
        'oi-1',
        'venue-1',
        'order-1',
        'item-1',
        'Coca-Cola',
        1500,
        2,
        OrderItemStatus.sent,
        null, // comments
        null, // updatedAt
      ]);
    });
  });

  group('PendingOp', () {
    final now = DateTime(2026, 5, 28, 10);
    final op = PendingOp(
      id: 1,
      venueId: 'venue-1',
      opType: PendingOpType.createOrder,
      payload: '{"order_id":"x"}',
      createdAt: now,
      attempts: 0,
    );

    test('props incluye todos los campos', () {
      expect(op.props, [
        1,
        'venue-1',
        PendingOpType.createOrder,
        '{"order_id":"x"}',
        now,
        0,
      ]);
    });

    test('igualdad por valor', () {
      final same = PendingOp(
        id: 1,
        venueId: 'venue-1',
        opType: PendingOpType.createOrder,
        payload: '{"order_id":"x"}',
        createdAt: now,
        attempts: 0,
      );
      expect(op, equals(same));
    });
  });
}
