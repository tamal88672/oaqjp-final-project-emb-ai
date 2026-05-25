import { useState, useEffect } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Plus, Search, Grid3X3, List, Package } from 'lucide-react';
import { getProducts, getCategories } from '../utils/api';

const statusColors = {
  available: 'bg-green-100 text-green-700',
  out_of_stock: 'bg-red-100 text-red-700',
  coming_soon: 'bg-amber-100 text-amber-700',
};

const statusLabels = {
  available: 'Available',
  out_of_stock: 'Out of Stock',
  coming_soon: 'Coming Soon',
};

export default function ProductList() {
  const [searchParams] = useSearchParams();
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [viewMode, setViewMode] = useState('grid');
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState(searchParams.get('category_id') || '');
  const [statusFilter, setStatusFilter] = useState('');
  const [sortBy, setSortBy] = useState('name');

  useEffect(() => {
    getCategories().then(setCategories).catch(() => {});
  }, []);

  useEffect(() => {
    setLoading(true);
    const params = {};
    if (search) params.search = search;
    if (categoryFilter) params.category_id = categoryFilter;
    if (statusFilter) params.status = statusFilter;
    if (sortBy) params.sort = sortBy;

    getProducts(params)
      .then((data) => {
        setProducts(Array.isArray(data) ? data : data.products || []);
      })
      .catch(() => setProducts([]))
      .finally(() => setLoading(false));
  }, [search, categoryFilter, statusFilter, sortBy]);

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Products</h1>
          <p className="text-sm text-gray-500 mt-1">Manage your handicraft collection</p>
        </div>
        <Link
          to="/products/new"
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors text-sm font-medium"
        >
          <Plus size={18} />
          Add Product
        </Link>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4 mb-6">
        <div className="flex flex-col md:flex-row gap-3">
          <div className="relative flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search products..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300 focus:border-transparent"
            />
          </div>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300 bg-white"
          >
            <option value="">All Categories</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300 bg-white"
          >
            <option value="">All Status</option>
            <option value="available">Available</option>
            <option value="out_of_stock">Out of Stock</option>
            <option value="coming_soon">Coming Soon</option>
          </select>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300 bg-white"
          >
            <option value="name">Sort by Name</option>
            <option value="price_asc">Price: Low to High</option>
            <option value="price_desc">Price: High to Low</option>
            <option value="newest">Newest First</option>
          </select>
          <div className="flex border border-gray-200 rounded-lg overflow-hidden">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-2 ${viewMode === 'grid' ? 'bg-amber-100 text-amber-700' : 'text-gray-400 hover:text-gray-600'}`}
            >
              <Grid3X3 size={18} />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`p-2 ${viewMode === 'list' ? 'bg-amber-100 text-amber-700' : 'text-gray-400 hover:text-gray-600'}`}
            >
              <List size={18} />
            </button>
          </div>
        </div>
      </div>

      {/* Products */}
      {loading ? (
        <div className="flex items-center justify-center h-48">
          <div className="animate-spin w-8 h-8 border-4 border-amber-500 border-t-transparent rounded-full" />
        </div>
      ) : products.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100 shadow-sm">
          <Package size={48} className="mx-auto text-gray-300 mb-3" />
          <p className="text-gray-500">No products found</p>
          <Link
            to="/products/new"
            className="inline-block mt-3 text-sm text-amber-600 hover:text-amber-700 font-medium"
          >
            Add your first product
          </Link>
        </div>
      ) : viewMode === 'grid' ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {products.map((product) => (
            <Link
              key={product.id}
              to={`/products/${product.id}`}
              className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden hover:shadow-md transition-shadow group"
            >
              <div className="h-44 bg-amber-50 overflow-hidden">
                {product.image_url ? (
                  <img
                    src={product.image_url}
                    alt={product.name}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <Package size={40} className="text-amber-200" />
                  </div>
                )}
              </div>
              <div className="p-4">
                <div className="flex items-start justify-between gap-2 mb-1">
                  <h3 className="font-semibold text-gray-800 text-sm truncate">{product.name}</h3>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium shrink-0 ${statusColors[product.status] || statusColors.available}`}>
                    {statusLabels[product.status] || product.status}
                  </span>
                </div>
                <p className="text-xs text-gray-400 mb-2">{product.category_name || 'Uncategorized'}</p>
                <div className="flex items-center justify-between">
                  <span className="text-amber-700 font-bold text-sm">
                    ${product.price_usd ? Number(product.price_usd).toFixed(2) : '0.00'}
                  </span>
                  {product.sku && (
                    <span className="text-xs text-gray-400">SKU: {product.sku}</span>
                  )}
                </div>
                {product.stock_quantity != null && (
                  <p className="text-xs text-gray-400 mt-1">
                    Stock: {product.stock_quantity}
                  </p>
                )}
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-100 text-left">
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Product</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden sm:table-cell">Category</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Price</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden md:table-cell">SKU</th>
                <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody>
              {products.map((product) => (
                <tr key={product.id} className="border-b border-gray-50 hover:bg-amber-50/30">
                  <td className="px-4 py-3">
                    <Link to={`/products/${product.id}`} className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-lg bg-amber-50 overflow-hidden shrink-0">
                        {product.image_url ? (
                          <img src={product.image_url} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Package size={16} className="text-amber-300" />
                          </div>
                        )}
                      </div>
                      <span className="text-sm font-medium text-gray-800 hover:text-amber-700">
                        {product.name}
                      </span>
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 hidden sm:table-cell">
                    {product.category_name || '-'}
                  </td>
                  <td className="px-4 py-3 text-sm font-medium text-amber-700">
                    ${product.price_usd ? Number(product.price_usd).toFixed(2) : '0.00'}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-400 hidden md:table-cell">
                    {product.sku || '-'}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusColors[product.status] || statusColors.available}`}>
                      {statusLabels[product.status] || product.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
