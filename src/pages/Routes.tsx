import { createBrowserRouter, Navigate, RouterProvider } from 'react-router-dom';
import OrderFunnel from '../hooks/orderFunnel';

const router = createBrowserRouter([
  { path: '/order', element: <OrderFunnel /> },
  { path: '*', element: <Navigate to="/order" replace /> },
]);

export function Routes() {
  return <RouterProvider router={router} />;
}
