import { colors, ListRow, Assets, Spacing, NavigationBar, NumericSpinner, Flex, Toast, FixedBottomCTA } from 'tosslib';
import { overlay } from 'overlay-kit';
import { CartItem } from '../hooks/types';
import { Item, Option } from '../api/model';
import { useMemo } from 'react';

interface CartPageProps {
  cartItems: CartItem[];
  items: Item[];
  options: Option[];
  onCheckout: () => Promise<void>;
  onBack: () => void;
  onRemoveItem: (itemId: number, selectionsByOptionId: Record<number, string[]>) => void;
  onUpdateQuantity: (itemId: number, selectionsByOptionId: Record<number, string[]>, newQuantity: number) => void;
}

function cartItemKey(cartItem: CartItem) {
  return `${cartItem.itemId}-${JSON.stringify(cartItem.selectionsByOptionId)}`;
}

export function CartPage({
  cartItems,
  items,
  options,
  onCheckout,
  onBack,
  onRemoveItem,
  onUpdateQuantity,
}: CartPageProps) {
  const itemMap = useMemo(() => new Map(items.map(item => [item.id, item])), [items]);
  const optionMap = useMemo(() => new Map(options.map(o => [o.id, o])), [options]);

  const cartItemsWithDetails = useMemo(() => {
    return cartItems
      .map(cartItem => {
        const item = itemMap.get(cartItem.itemId);
        if (!item) return null;

        const optionDescriptions = Object.entries(cartItem.selectionsByOptionId)
          .map(([optionId, selectedLabels]) => {
            const option = optionMap.get(Number(optionId));
            if (!option) return '';
            return selectedLabels
              .map(label => {
                const idx = option.labels.indexOf(label);
                const price = option.prices?.[idx] ?? 0;
                return price > 0 ? `${label}(+${price.toLocaleString()}원)` : label;
              })
              .join(', ');
          })
          .filter(Boolean)
          .join(', ');

        return { ...cartItem, item, optionDescriptions };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null);
  }, [cartItems, itemMap, optionMap]);

  const totalCount = cartItems.reduce((sum, item) => sum + item.quantity, 0);
  const totalAmount = cartItems.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);

  return (
    <div>
      <NavigationBar
        title="장바구니"
        left={
          <Assets.Icon
            name="icon-arrow-left-mono"
            shape={{ width: 32, height: 32 }}
            onClick={onBack}
            style={{ cursor: 'pointer' }}
          />
        }
      />

      {cartItemsWithDetails.map(cartItem => (
        <div key={cartItemKey(cartItem)}>
          <ListRow
            contents={
              <ListRow.Texts
                type="3RowTypeA"
                top={cartItem.item.title}
                topProps={{ color: colors.grey800, fontWeight: 'bold' }}
                middle={cartItem.optionDescriptions || '기본 옵션'}
                middleProps={{ color: colors.grey600, fontSize: 13, fontWeight: 'medium' }}
                bottom={`${(cartItem.unitPrice * cartItem.quantity).toLocaleString()}원`}
                bottomProps={{ color: colors.grey700, fontSize: 13, fontWeight: 'medium' }}
              />
            }
            right={
              <Assets.Icon
                name="icon-x-circle-mono"
                color={colors.grey400}
                onClick={() => onRemoveItem(cartItem.itemId, cartItem.selectionsByOptionId)}
                style={{ cursor: 'pointer' }}
              />
            }
          />
          <Spacing size={16} />
          <Flex direction="row" justifyContent="flex-end" css={{ padding: '0 24px' }}>
            <NumericSpinner
              size="small"
              number={cartItem.quantity}
              onNumberChange={n => {
                if (n < 1) {
                  overlay.open(({ isOpen, close }) => (
                    <Toast isOpen={isOpen} close={close} type="warn" message="1개 이상은 주문해주세요" delay={1500} />
                  ));
                  return;
                }
                onUpdateQuantity(cartItem.itemId, cartItem.selectionsByOptionId, n);
              }}
            />
          </Flex>
          <Spacing size={8} />
        </div>
      ))}

      <Spacing size={120} />
      <FixedBottomCTA
        onClick={async () => {
          try {
            await onCheckout();
          } catch {
            overlay.open(({ isOpen, close }) => (
              <Toast isOpen={isOpen} close={close} type="warn" message="주문 처리 중 오류가 발생했습니다" delay={1500} />
            ));
          }
        }}
      >
        {totalCount}개 {totalAmount.toLocaleString()}원 결제하기
      </FixedBottomCTA>
    </div>
  );
}
