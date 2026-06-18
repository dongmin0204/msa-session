import { colors, FixedBottomCTA, Lottie, NavigationBar, Spacing, Top } from 'tosslib';
import { useEffect, useState } from 'react';
import { orderApi } from '../api';
import { OrderDetailResponse } from '../api/model';

interface OrderCompletePageProps {
  orderId?: string;
  onBackToMenu?: () => void;
}

export function OrderCompletePage({ orderId, onBackToMenu }: OrderCompletePageProps = {}) {
  const [orderDetail, setOrderDetail] = useState<OrderDetailResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!orderId) {
      setError('주문 ID가 없습니다.');
      setLoading(false);
      return;
    }

    const fetchOrderDetail = async () => {
      try {
        const detail = await orderApi.getOrder(orderId);
        setOrderDetail(detail);
      } catch (err) {
        if (err && typeof err === 'object' && 'status' in err && err.status === 404) {
          setError('주문을 찾을 수 없어요');
        } else {
          setError('주문 정보를 불러오는데 실패했습니다.');
        }
      } finally {
        setLoading(false);
      }
    };

    fetchOrderDetail();
  }, [orderId]);

  // 총 개수 계산
  const totalCount = orderDetail?.items?.reduce((sum, item) => sum + item.quantity, 0) || 0;

  const handleConfirm = () => {
    if (onBackToMenu) {
      onBackToMenu();
    }
  };

  if (loading) {
    return (
      <>
        <NavigationBar title="주문 완료" />
        <Spacing size={40} />
        <div style={{ textAlign: 'center', color: colors.grey600 }}>주문 정보를 불러오는 중...</div>
      </>
    );
  }

  if (error || !orderDetail) {
    return (
      <>
        <NavigationBar title="주문 완료" />
        <Spacing size={40} />
        <div style={{ textAlign: 'center', color: colors.red500 }}>{error}</div>
        <Spacing size={80} />
        <FixedBottomCTA onClick={handleConfirm}>메뉴로 돌아가기</FixedBottomCTA>
      </>
    );
  }

  return (
    <>
      <NavigationBar title="주문 완료" />
      <Spacing size={40} />
      <Lottie src="https://static.toss.im/lotties-common/check-spot.json" css={{ width: 80 }} />
      <Top
        title={<Top.TitleParagraph color={colors.grey900}>주문이 완료됐어요</Top.TitleParagraph>}
        subtitle={
          <Top.SubTitleParagraph>
            {totalCount}개 {orderDetail?.totalPrice?.toLocaleString() || '0'}원
          </Top.SubTitleParagraph>
        }
      />
      <Spacing size={80} />
      <FixedBottomCTA onClick={handleConfirm}>확인했어요</FixedBottomCTA>
    </>
  );
}