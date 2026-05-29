import { useState, useEffect } from 'react';
import { Search, Plus, Minus, Save, Warehouse } from 'lucide-react';
import { getInventory, updateInventory } from '../utils/api';

const stockBadge = (status) => {
  switch (status) {
    case 'out':
      return 'bg-red-100 text-red-700';
    case 'low':
      return 'bg-amber-100 text-amber-700';
    default:
      return 'bg-green-100 text-green-700';
  }
};

const stockLabel = (status) => {
  switch (status) {
    case 'out':
      return 'Out of Stock';
    case 'low':
      return 'Low Stock';
    default:
      return 'OK';
  }
};

function getStockStatus(item) {
  if ((item.stock_quantity ?? 0) <= 0) return 'out';
  if ((item.stock_quantity ?? 0) <= (item.min_stock ?? 10)) return 'low';
  return 'ok';
}

export default function InventoryPage() {
  const [inventory, setInventory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('all');
  const [adjustments, setAdjustments] = useState({});
  const [saving, setSaving] = useState({});

  useEffect(() => {
    fetchInventory();
  }, []);

  const fetchInventory = () => {
    setLoading(true);
    getInventory()
      .then((data) => setInventory(Array.isArray(data) ? data : []))
      .catch(() => setInventory([]))
      .finally(() => setLoading(false));
  };

  const handleAdjust = (productId, change) => {
    setAdjustments(prev => {
      const current = prev[productId] ?? inventory.find(i => i.product_id === productId)?.stock_quantity ?? 0;
      const newVal = Math.max(0, current + change);
      return { ...prev, [productId]: newVal };
    });
  };

  const handleSave = async (productId) => {
    const qty = adjustments[productId];
    if (qty == null) return;
    setSaving(prev => ({ ...prev, [productId]: true }));
    try {
      await updateInventory(productId, { quantity: qty });
      setInventory(prev =>
        prev.map(item =>
          item.product_id === productId
            ? { ...item, stock_quantity: qty }
            : item
        )
      );
      setAdjustments(prev => {
        const next = { ...prev };
        delete next[productId];
        return next;
      });
    } catch (err) {
      alert('Failed to update inventory');
    } finally {
      setSaving(prev => ({ ...prev, [productId]: false }));
    }
  };

  const filtered = inventory.filter(item => {
    const status = getStockStatus(item);
    if (filter === 'low' && status !== 'low') return false;
    if (filter === 'out' && status !== 'out') return false;

    if (search) {
      const q = search.toLowerCase();
      return (
        (item.product_name || '').toLowerCase().includes(q) ||
        (item.sku || '').toLowerCase().includes(q)
      );
    }
    return true;
  });

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-amber-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Inventory</h1>
        <p className="text-sm text-gray-500 mt-1">Track and manage stock levels</p>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4 mb-6">
        <div className="flex flex-col sm:flex-row gap-3">
          <div className="relative flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search by product name or SKU..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300"
            />
          </div>
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300 bg-white"
          >
            <option value="all">All Items</option>
            <option value="low">Low Stock Only</option>
            <option value="out">Out of Stock Only</option>
          </select>
        </div>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100 shadow-sm">
          <Warehouse size={48} className="mx-auto text-gray-300 mb-3" />
          <p className="text-gray-500">No inventory items found</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-100 text-left">
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Product</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden sm:table-cell">SKU</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden md:table-cell">Category</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase text-center">Stock</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden lg:table-cell text-center">Min Stock</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden lg:table-cell">Location</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase text-center">Adjust</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((item) => {
                const status = getStockStatus(item);
                const currentQty = adjustments[item.product_id] ?? item.stock_quantity ?? 0;
                const hasChange = adjustments[item.product_id] != null;

                return (
                  <tr key={item.product_id} className="border-b border-gray-50 hover:bg-amber-50/30">
                    <td className="px-4 py-3 text-sm font-medium text-gray-800">
                      {item.product_name || 'Unknown'}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 hidden sm:table-cell">
                      {item.sku || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 hidden md:table-cell">
                      {item.category_name || '-'}
                    </td>
                    <td className="px-4 py-3 text-center">
                      <span className={`text-sm font-bold ${hasChange ? 'text-amber-600' : 'text-gray-800'}`}>
                        {currentQty}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 hidden lg:table-cell text-center">
                      {item.min_stock ?? 10}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${stockBadge(status)}`}>
                        {stockLabel(status)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 hidden lg:table-cell">
                      {item.warehouse_location || '-'}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center justify-center gap-1">
                        <button
                          onClick={() => handleAdjust(item.product_id, -1)}
                          disabled={currentQty <= 0}
                          className="p-1 rounded hover:bg-red-50 text-gray-400 hover:text-red-600 transition-colors disabled:opacity-30"
                        >
                          <Minus size={14} />
                        </button>
                        <button
                          onClick={() => handleAdjust(item.product_id, 1)}
                          className="p-1 rounded hover:bg-green-50 text-gray-400 hover:text-green-600 transition-colors"
                        >
                          <Plus size={14} />
                        </button>
                        {hasChange && (
                          <button
                            onClick={() => handleSave(item.product_id)}
                            disabled={saving[item.product_id]}
                            className="p-1 rounded hover:bg-amber-50 text-amber-500 hover:text-amber-700 transition-colors ml-1"
                          >
                            <Save size={14} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
