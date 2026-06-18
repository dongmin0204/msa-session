/**
 * 주문 funnel 단계 타입 정의
 */
export type CartItem = {
  itemId: number;
  quantity: number;
  selectionsByOptionId: Record<number, string[]>;
  unitPrice: number; // 개별 아이템의 단가
};

export type OrderSteps = {
  Category: object;
  Menu: { category?: string };
  Options: {
    itemId?: number;
    quantity?: number;
    selectionsByOptionId: Record<number, string[]>;
    category?: string;
  };
  Cart: { items: CartItem[]; totalPrice: number };
  Complete: { orderId: string };
};
