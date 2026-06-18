export interface CategoriesResponse {
  categories: string[];
}

export interface ItemsResponse {
  items: Item[];
}

export interface ItemResponse {
  item: Item;
}

export interface OptionsResponse {
  options: Option[];
}

export interface OrderRequest {
  totalPrice: number;
  items: OrderItem[];
}

export interface OrderResponse {
  orderId: string;
}

export interface OrderDetailResponse {
  totalPrice: number;
  items: OrderItem[];
}

export type Item = {
  id: number;
  category: string;
  title: string;
  description: string;
  price: number;
  iconImg: string;
  optionIds?: number[];
};

export type Option = {
  id: number;
  name: string;
  type: 'grid' | 'select' | 'list';
  col?: 1 | 2 | 3;
  labels: string[];
  icons?: string[];
  prices?: number[];
  minCount?: number;
  maxCount?: number;
};

export interface OrderItem {
  itemId: number;
  quantity: number;
  options: Array<{
    optionId: number;
    labels: string[];
  }>;
}
