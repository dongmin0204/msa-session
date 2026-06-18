import {
  Assets,
  Border,
  colors,
  ListHeader,
  Paragraph,
  Post,
  Top,
  Checkbox,
  SelectBottomSheet,
  ListRow,
  Spacing,
  GridList,
  NavigationBar,
  Flex,
  NumericSpinner,
  Badge,
  FixedBottomCTA,
  Toast,
} from 'tosslib';
import { useEffect, useMemo, useState, useCallback } from 'react';
import { Item, Option } from '../api/model';
import { catalogApi } from '../api';
import { overlay } from 'overlay-kit';

interface LineItem {
  item: Item;
  selected: Record<number, string[]>;
  quantity: number;
  totalPrice: number;
}

type Props = {
  items: Item[];
  options: Option[];
  itemId: number;
  initialQuantity?: number;
  initialSelections?: Record<number, string[]>;
  onChange?: (next: { quantity?: number; selectionsByOptionId?: Record<number, string[]> }) => void;
  onAddToCart: (lineItem: LineItem) => void;
  onBack: () => void;
};

export function DetailPage({
  items,
  options,
  itemId,
  initialQuantity = 1,
  initialSelections = {},
  onChange,
  onAddToCart,
  onBack,
}: Props) {
  const baseItem = items.find(i => i.id === itemId);
  const [detailItem, setDetailItem] = useState<Item | null>(null);
  const [loading, setLoading] = useState(true);
  const [quantity, setQuantity] = useState(initialQuantity);
  const [selected, setSelected] = useState<Record<number, string[]>>(initialSelections);

  useEffect(() => {
    let mounted = true;
    catalogApi.getDetailedItemById(itemId).then(it => {
      if (mounted) setDetailItem(it);
    }).finally(() => {
      if (mounted) setLoading(false);
    });
    return () => { mounted = false; };
  }, [itemId]);

  const item = detailItem ?? baseItem;
  const optionIds = useMemo(() => detailItem?.optionIds ?? [], [detailItem]);
  const optionMap = useMemo(() => new Map(options.map(o => [o.id, o] as const)), [options]);

  const filteredOptions = useMemo(
    () => optionIds.map(oid => optionMap.get(oid)).filter((o): o is Option => Boolean(o)),
    [optionIds, optionMap],
  );

  const showToast = useCallback((message: string) => {
    overlay.open(({ isOpen, close }) => (
      <Toast isOpen={isOpen} close={close} type="warn" message={message} delay={1500} />
    ));
  }, []);

  const toggle = useCallback(
    (opt: Option, label: string) => {
      setSelected(prev => {
        const cur = prev[opt.id] ?? [];
        let next: string[];

        if (opt.type === 'grid' || opt.type === 'select') {
          next = cur.includes(label) ? [] : [label];
        } else {
          if (cur.includes(label)) {
            next = cur.filter(x => x !== label);
          } else {
            const max = opt.maxCount ?? opt.labels.length;
            if (cur.length >= max) {
              showToast('최대 선택 갯수 만큼 선택 할 수 있어요');
              return prev;
            }
            next = [...cur, label];
          }
        }

        const newSelected = { ...prev, [opt.id]: next };
        onChange?.({ selectionsByOptionId: newSelected });
        return newSelected;
      });
    },
    [onChange, showToast],
  );

  const isValid = useMemo(() => {
    return filteredOptions.every(opt => {
      const chosen = selected[opt.id] ?? [];
      if (opt.type === 'grid') return chosen.length > 0;
      if (opt.type === 'list') return chosen.length >= (opt.minCount ?? 0);
      return true;
    });
  }, [filteredOptions, selected]);

  const totalPrice = useMemo(() => {
    if (!item) return 0;
    let sum = item.price;
    for (const opt of filteredOptions) {
      for (const label of selected[opt.id] ?? []) {
        const idx = opt.labels.indexOf(label);
        if (idx >= 0) sum += opt.prices?.[idx] ?? 0;
      }
    }
    return sum * quantity;
  }, [item, filteredOptions, selected, quantity]);

  const handleAddToCart = useCallback(() => {
    for (const opt of filteredOptions) {
      const chosen = selected[opt.id] ?? [];
      const required =
        opt.type === 'grid' || (opt.type === 'list' && (opt.minCount ?? 0) > 0);
      if (required && chosen.length < (opt.minCount ?? 1)) {
        showToast(`${opt.name}을 선택해주세요`);
        return;
      }
    }
    onAddToCart({ item: item!, selected, quantity, totalPrice });
  }, [filteredOptions, selected, item, quantity, totalPrice, showToast, onAddToCart]);

  if (!item || loading) return <div>로딩 중...</div>;

  return (
    <div>
      <NavigationBar
        left={
          <Assets.Icon
            name="icon-arrow-left-mono"
            shape={{ width: 32, height: 32 }}
            onClick={onBack}
            style={{ cursor: 'pointer' }}
          />
        }
      />
      <Spacing size={20} />
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <Assets.Image shape={{ width: 170 }} src={item.iconImg} />
      </div>
      <Top
        title={<Top.TitleParagraph color={colors.grey900}>{item.title}</Top.TitleParagraph>}
        subtitle={<Top.SubTitleParagraph>{item.description}</Top.SubTitleParagraph>}
      />
      <Post.H2 paddingBottom={24}>
        <Flex direction="row" justifyContent="space-between" alignItems="center">
          <Paragraph.Text>{item.price.toLocaleString()}원</Paragraph.Text>
          <NumericSpinner
            number={quantity}
            onNumberChange={n => {
              if (n < 1) {
                showToast('1개 이상은 주문해주세요');
                return;
              }
              setQuantity(n);
            }}
          />
        </Flex>
      </Post.H2>
      <Border height={16} />

      {filteredOptions.map(opt => {
        const chosen = selected[opt.id] ?? [];
        const required = opt.type === 'grid' || (opt.type === 'list' && (opt.minCount ?? 0) > 0);

        return (
          <div key={opt.id}>
            <ListHeader
              title={
                <ListHeader.TitleParagraph color={colors.grey800} fontWeight="bold">
                  {opt.name}
                  {required && <Badge css={{ marginLeft: 8 }}>필수</Badge>}
                </ListHeader.TitleParagraph>
              }
            />

            {opt.type === 'grid' && (
              <GridList column={opt.col ?? 2}>
                {opt.labels.map((label, i) => (
                  <GridList.Item
                    key={label}
                    image={opt.icons?.[i] ? <Assets.Icon name={opt.icons[i]!} /> : undefined}
                    checked={chosen.includes(label)}
                    onClick={() => toggle(opt, label)}
                  >
                    {label}
                  </GridList.Item>
                ))}
              </GridList>
            )}

            {opt.type === 'select' && (
              <SelectBottomSheet
                title={`${opt.name}을 선택해주세요`}
                onChange={value => {
                  setSelected(prev => {
                    const newSelected = { ...prev, [opt.id]: value ? [String(value)] : [] };
                    onChange?.({ selectionsByOptionId: newSelected });
                    return newSelected;
                  });
                }}
                value={chosen[0] ?? ''}
              >
                {opt.labels.map((label, i) => (
                  <SelectBottomSheet.Option key={label} value={label}>
                    <ListRow
                      contents={
                        (opt.prices?.[i] ?? 0) ? (
                          <ListRow.Texts
                            type="2RowTypeA"
                            top={label}
                            topProps={{ color: colors.grey700 }}
                            bottom={`+${opt.prices![i]!.toLocaleString()}원`}
                            bottomProps={{ color: colors.grey700 }}
                          />
                        ) : (
                          <ListRow.Texts type="1RowTypeA" top={label} topProps={{ color: colors.grey700 }} />
                        )
                      }
                      withPadding={false}
                    />
                  </SelectBottomSheet.Option>
                ))}
              </SelectBottomSheet>
            )}

            {opt.type === 'list' &&
              opt.labels.map((label, i) => (
                <ListRow
                  key={label}
                  contents={
                    <ListRow.Texts
                      type="2RowTypeA"
                      top={label}
                      topProps={{ color: colors.grey800 }}
                      bottom={`+${(opt.prices?.[i] ?? 0).toLocaleString()}원`}
                      bottomProps={{ color: colors.grey600 }}
                    />
                  }
                  right={
                    <Checkbox.Line
                      checked={chosen.includes(label)}
                      size={30}
                      onChange={() => toggle(opt, label)}
                    />
                  }
                />
              ))}

            <Spacing size={16} />
            <Border height={1} />
          </div>
        );
      })}

      <Spacing size={80} />
      <FixedBottomCTA disabled={!isValid} onClick={handleAddToCart}>
        {quantity}개 {totalPrice.toLocaleString()}원 담기
      </FixedBottomCTA>
    </div>
  );
}
