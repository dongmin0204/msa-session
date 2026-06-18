import { FixedBottomCTA, ListRow, Top, colors, Tab, Spacing } from 'tosslib';
import { Item } from '../api/model';

interface MenuPageProps {
  items: Item[];
  categories: string[];
  selectedCategory: string;
  cartSummary: { totalCount: number; totalAmount: number };
  onSelectCategory: (category: string) => void;
  onSelectItem: (itemId: number) => void;
  onOpenCart: () => void;
}

export function MenuPage({
  items,
  categories,
  selectedCategory,
  cartSummary,
  onSelectCategory,
  onSelectItem,
  onOpenCart,
}: MenuPageProps) {
  const filteredItems = items.filter(item => item.category === selectedCategory);

  const ctaText =
    cartSummary.totalCount > 0
      ? `장바구니 보기 · ${cartSummary.totalCount}개 · ${cartSummary.totalAmount.toLocaleString()}원`
      : '장바구니 보기';

  return (
    <>
      <Top title={<Top.TitleParagraph color={colors.grey900}>커피 사일로</Top.TitleParagraph>} />
      <Tab style={{ backgroundColor: colors.background }} onChange={onSelectCategory}>
        {categories.map(category => (
          <Tab.Item key={category} value={category} selected={category === selectedCategory}>
            {category}
          </Tab.Item>
        ))}
      </Tab>
      {filteredItems.map(item => (
        <ListRow
          key={item.id}
          left={<ListRow.Image src={item.iconImg} style={{ marginRight: 16 }} />}
          onClick={() => onSelectItem(item.id)}
          contents={
            <ListRow.Texts
              type="2RowTypeA"
              top={item.title}
              topProps={{ color: colors.grey800, fontWeight: 'bold' }}
              bottom={`${item.price.toLocaleString()}원`}
              bottomProps={{ color: colors.grey600 }}
            />
          }
        />
      ))}
      <Spacing size={80} />
      <FixedBottomCTA onClick={onOpenCart}>{ctaText}</FixedBottomCTA>
    </>
  );
}
