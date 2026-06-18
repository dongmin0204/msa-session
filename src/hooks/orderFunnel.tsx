import { useFunnel } from '@use-funnel/react-router-dom';
import type { OrderSteps, CartItem } from './types';
import { MenuPage } from '../pages/MenuPage';
import { DetailPage } from '../pages/DetailPage';
import { CartPage } from '../pages/CartPage';
import { OrderCompletePage } from '../pages/OrderComplete';
import { catalogApi, orderApi } from '../api';
import { useState, useEffect, useMemo, useCallback } from 'react';
import { Item, Option, OrderItem } from '../api/model';
import { overlay } from 'overlay-kit';
import { Toast } from 'tosslib';

function showErrorToast(message: string) {
  overlay.open(({ isOpen, close }) => (
    <Toast isOpen={isOpen} close={close} type="warn" message={message} delay={1500} />
  ));
}

function isSameSelection(a: Record<number, string[]>, b: Record<number, string[]>) {
  const keysA = Object.keys(a).sort();
  const keysB = Object.keys(b).sort();
  if (keysA.length !== keysB.length) return false;
  return keysA.every((key, i) => {
    if (keysB[i] !== key) return false;
    const vA = a[Number(key)].slice().sort();
    const vB = b[Number(key)].slice().sort();
    return vA.length === vB.length && vA.every((v, j) => v === vB[j]);
  });
}

export default function OrderFunnel() {
  const funnel = useFunnel<OrderSteps>({
    id: 'coffee-order',
    initial: { step: 'Category', context: {} },
  });

  const [items, setItems] = useState<Item[]>([]);
  const [options, setOptions] = useState<Option[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    Promise.all([catalogApi.getItems(), catalogApi.getOptions(), catalogApi.getCategories()])
      .then(([itemsData, optionsData, categoriesData]) => {
        setItems(itemsData);
        setOptions(optionsData);
        setCategories(categoriesData);
      })
      .catch(() => showErrorToast('데이터를 불러오는데 실패했습니다'))
      .finally(() => setIsLoading(false));
  }, []);

  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [lastSelectedCategory, setLastSelectedCategory] = useState('');

  const calculateTotalPrice = useCallback(
    (list: CartItem[]) => list.reduce((sum, ci) => sum + ci.unitPrice * ci.quantity, 0),
    [],
  );

  const cartSummary = useMemo(() => {
    const totalCount = cartItems.reduce((sum, ci) => sum + ci.quantity, 0);
    return { totalCount, totalAmount: calculateTotalPrice(cartItems) };
  }, [cartItems, calculateTotalPrice]);

  const addToCart = useCallback(
    (itemId: number, quantity: number, selectionsByOptionId: Record<number, string[]>, totalPriceInCart: number) => {
      const unitPrice = totalPriceInCart / quantity;
      setCartItems(prev => {
        const idx = prev.findIndex(
          ci => ci.itemId === itemId && isSameSelection(ci.selectionsByOptionId, selectionsByOptionId),
        );
        if (idx >= 0) {
          const updated = [...prev];
          updated[idx] = { ...updated[idx], quantity: updated[idx].quantity + quantity };
          return updated;
        }
        return [...prev, { itemId, quantity, selectionsByOptionId, unitPrice }];
      });
    },
    [],
  );

  const removeFromCart = useCallback(
    (itemId: number, selectionsByOptionId: Record<number, string[]>) => {
      setCartItems(prev =>
        prev.filter(ci => !(ci.itemId === itemId && isSameSelection(ci.selectionsByOptionId, selectionsByOptionId))),
      );
    },
    [],
  );

  const updateCartQuantity = useCallback(
    (itemId: number, selectionsByOptionId: Record<number, string[]>, newQuantity: number) => {
      if (newQuantity <= 0) {
        removeFromCart(itemId, selectionsByOptionId);
        return;
      }
      setCartItems(prev =>
        prev.map(ci =>
          ci.itemId === itemId && isSameSelection(ci.selectionsByOptionId, selectionsByOptionId)
            ? { ...ci, quantity: newQuantity }
            : ci,
        ),
      );
    },
    [removeFromCart],
  );

  if (isLoading) return <div>로딩 중...</div>;

  return (
    <funnel.Render
      Category={funnel.Render.with({
        events: {
          카테고리선택: (category: string, { history }) => {
            setLastSelectedCategory(category);
            history.push('Menu', prev => ({ ...prev, category }));
          },
          아이템선택: (itemId: number, { history }) => {
            history.push('Options', prev => ({
              ...prev,
              itemId,
              quantity: 1,
              selectionsByOptionId: {},
              category: lastSelectedCategory || categories[0] || '커피',
            }));
          },
        },
        render({ dispatch }) {
          return (
            <MenuPage
              items={items}
              categories={categories}
              selectedCategory={lastSelectedCategory || categories[0] || ''}
              cartSummary={cartSummary}
              onSelectCategory={c => dispatch('카테고리선택', c)}
              onSelectItem={id => dispatch('아이템선택', id)}
              onOpenCart={() =>
                funnel.history.push('Cart', prev => ({
                  ...prev,
                  items: cartItems,
                  totalPrice: calculateTotalPrice(cartItems),
                }))
              }
            />
          );
        },
      })}
      Menu={({ context, history }) => (
        <MenuPage
          items={items}
          categories={categories}
          selectedCategory={context.category || categories[0] || ''}
          cartSummary={cartSummary}
          onSelectCategory={category => {
            setLastSelectedCategory(category);
            history.push('Menu', prev => ({ ...prev, category }));
          }}
          onSelectItem={itemId =>
            history.push('Options', prev => ({
              ...prev,
              itemId,
              quantity: 1,
              selectionsByOptionId: {},
              category: context.category,
            }))
          }
          onOpenCart={() =>
            funnel.history.push('Cart', prev => ({
              ...prev,
              items: cartItems,
              totalPrice: calculateTotalPrice(cartItems),
            }))
          }
        />
      )}
      Options={({ context, history }) => (
        <DetailPage
          items={items}
          options={options}
          itemId={context.itemId!}
          initialQuantity={context.quantity}
          initialSelections={context.selectionsByOptionId}
          onChange={next => history.replace('Options', { ...context, ...next })}
          onAddToCart={lineItem => {
            addToCart(lineItem.item.id, lineItem.quantity, lineItem.selected, lineItem.totalPrice);
            const updatedItems = [...cartItems];
            const idx = updatedItems.findIndex(
              ci =>
                ci.itemId === lineItem.item.id &&
                isSameSelection(ci.selectionsByOptionId, lineItem.selected),
            );
            const unitPrice = lineItem.totalPrice / lineItem.quantity;
            if (idx >= 0) {
              updatedItems[idx] = {
                ...updatedItems[idx],
                quantity: updatedItems[idx].quantity + lineItem.quantity,
              };
            } else {
              updatedItems.push({
                itemId: lineItem.item.id,
                quantity: lineItem.quantity,
                selectionsByOptionId: lineItem.selected,
                unitPrice,
              });
            }
            history.push('Cart', prev => ({
              ...prev,
              items: updatedItems,
              totalPrice: calculateTotalPrice(updatedItems),
            }));
          }}
          onBack={() => history.back()}
        />
      )}
      Cart={({ context, history }) => (
        <CartPage
          cartItems={context.items ?? []}
          items={items}
          options={options}
          onCheckout={async () => {
            if (!context.items?.length) {
              showErrorToast('장바구니가 비어있습니다');
              return;
            }
            const orderItems: OrderItem[] = context.items.map(ci => ({
              itemId: ci.itemId,
              quantity: ci.quantity,
              options: Object.entries(ci.selectionsByOptionId).map(([optionId, labels]) => ({
                optionId: Number(optionId),
                labels,
              })),
            }));
            const orderId = await orderApi.createOrder({
              totalPrice: context.totalPrice,
              items: orderItems,
            });
            setCartItems([]);
            history.push('Complete', prev => ({ ...prev, orderId }));
          }}
          onBack={() => history.back()}
          onRemoveItem={(itemId, sel) => {
            removeFromCart(itemId, sel);
            const updated = cartItems.filter(
              ci => !(ci.itemId === itemId && isSameSelection(ci.selectionsByOptionId, sel)),
            );
            if (updated.length === 0) {
              history.push('Category', {});
            } else {
              history.replace('Cart', prev => ({
                ...prev,
                items: updated,
                totalPrice: calculateTotalPrice(updated),
              }));
            }
          }}
          onUpdateQuantity={(itemId, sel, qty) => {
            updateCartQuantity(itemId, sel, qty);
            const updated = cartItems.map(ci =>
              ci.itemId === itemId && isSameSelection(ci.selectionsByOptionId, sel)
                ? { ...ci, quantity: qty }
                : ci,
            );
            history.replace('Cart', prev => ({
              ...prev,
              items: updated,
              totalPrice: calculateTotalPrice(updated),
            }));
          }}
        />
      )}
      Complete={({ context, history }) => (
        <OrderCompletePage orderId={context.orderId} onBackToMenu={() => history.push('Category', {})} />
      )}
    />
  );
}
