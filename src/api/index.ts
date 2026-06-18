import { http } from 'tosslib';
import type {
  Item,
  Option,
  CategoriesResponse,
  ItemsResponse,
  ItemResponse,
  OptionsResponse,
  OrderRequest,
  OrderResponse,
  OrderDetailResponse,
} from './model';

export const catalogApi = {
  async getCategories(): Promise<string[]> {
    const response = await http.get<CategoriesResponse>('/api/catalog/categories');
    return response.categories;
  },

  async getItems(): Promise<Item[]> {
    const { items } = await http.get<ItemsResponse>('/api/catalog/items');
    return items;
  },

  async getDetailedItemById(itemId: number): Promise<Item> {
    const { item } = await http.get<ItemResponse>(`/api/catalog/items/${itemId}`);
    return item;
  },

  async getOptions(): Promise<Option[]> {
    const { options } = await http.get<OptionsResponse>('/api/catalog/options');
    return options;
  },
};

export const orderApi = {
  async createOrder(orderData: OrderRequest): Promise<string> {
    const response = await http.post<OrderResponse>('/api/orders', { json: orderData });
    return response.orderId;
  },

  async getOrder(orderId: string): Promise<OrderDetailResponse> {
    const response = await http.get<{ order: OrderDetailResponse }>(`/api/orders/${orderId}`);
    return response.order;
  },
};
