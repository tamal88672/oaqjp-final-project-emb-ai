import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import {
  LayoutDashboard,
  Package,
  FolderOpen,
  Warehouse,
  BarChart3,
  Truck,
  Menu,
  X,
} from 'lucide-react';

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/products', icon: Package, label: 'Products' },
  { to: '/categories', icon: FolderOpen, label: 'Categories' },
  { to: '/inventory', icon: Warehouse, label: 'Inventory' },
  { to: '/reports', icon: BarChart3, label: 'Reports' },
  { to: '/suppliers', icon: Truck, label: 'Suppliers' },
];

export default function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="flex min-h-screen bg-[#faf8f5]">
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/40 z-30 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`fixed lg:static inset-y-0 left-0 z-40 w-64 bg-white border-r border-amber-100 shadow-sm transform transition-transform duration-200 ease-in-out ${
          sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        <div className="flex flex-col h-full">
          {/* Brand */}
          <div className="p-5 border-b border-amber-100">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-amber-500 to-amber-700 flex items-center justify-center">
                <span className="text-white text-lg font-bold">B</span>
              </div>
              <div>
                <h1 className="text-lg font-bold text-amber-900 leading-tight">
                  Bharatiya
                </h1>
                <p className="text-xs text-amber-600 tracking-wide">
                  Handicrafts Trade
                </p>
              </div>
            </div>
            {/* Decorative line */}
            <div className="mt-3 flex gap-1">
              <div className="h-0.5 flex-1 bg-amber-300 rounded" />
              <div className="h-0.5 w-2 bg-amber-500 rounded" />
              <div className="h-0.5 flex-1 bg-amber-300 rounded" />
            </div>
          </div>

          {/* Navigation */}
          <nav className="flex-1 p-3 space-y-1">
            {navItems.map(({ to, icon: Icon, label }) => (
              <NavLink
                key={to}
                to={to}
                end={to === '/'}
                onClick={() => setSidebarOpen(false)}
                className={({ isActive }) =>
                  `flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                    isActive
                      ? 'bg-amber-50 text-amber-800 border border-amber-200'
                      : 'text-gray-600 hover:bg-amber-50/50 hover:text-amber-700'
                  }`
                }
              >
                <Icon size={18} />
                {label}
              </NavLink>
            ))}
          </nav>

          {/* Footer */}
          <div className="p-4 border-t border-amber-100">
            <p className="text-xs text-gray-400 text-center">
              Crafted with care
            </p>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Mobile header */}
        <header className="lg:hidden bg-white border-b border-amber-100 px-4 py-3 flex items-center gap-3">
          <button
            onClick={() => setSidebarOpen(true)}
            className="p-2 rounded-lg hover:bg-amber-50 text-gray-600"
          >
            <Menu size={20} />
          </button>
          <span className="font-bold text-amber-900">Bharatiya Handicrafts</span>
        </header>

        {/* Page content */}
        <main className="flex-1 p-4 md:p-6 lg:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
