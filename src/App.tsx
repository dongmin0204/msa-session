import { OverlayProvider } from 'overlay-kit';
import { GlobalPortal, GlobalStyles } from 'tosslib';
import { Routes } from './pages/Routes';

export function App() {
  return (
    <>
      <GlobalStyles />
      <OverlayProvider>
        <GlobalPortal.Provider>
          <Routes />
        </GlobalPortal.Provider>
      </OverlayProvider>
    </>
  );
}
