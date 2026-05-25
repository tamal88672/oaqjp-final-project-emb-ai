import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ArrowLeft, Edit, Trash2, Plus, Minus, Package, MapPin, User } from 'lucide-react';
import Modal from '../components/Modal';
import { getProduct, deleteProduct, updateInventory } from '../utils/api';

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

export default function ProductDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [deleteModal, setDeleteModal] = useState(false);
  const [adjusting, setAdjusting] = useState(false);

  const fetchProduct = () => {
    setLoading(true);
    getProduct(id)
      .then(setProduct)
      .catch(() => navigate('/products'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchProduct();
  }, [id]);

  const handleDelete = async () => {
    try {
      await deleteProduct(id);
      navigate('/products');
    } catch (err) {
      alert('Failed to delete product');
    }
  };

  const handleStockAdjust = async (change) => {
    if (adjusting) return;
    setAdjusting(true);
    try {
      const newQty = (product.stock_quantity || 0) + change;
      if (newQty < 0) return;
      await updateInventory(id, { quantity: newQty });
      setProduct(prev => ({ ...prev, stock_quantity: newQty }));
    } catch (err) {
      alert('Failed to update stock');
    } finally {
      setAdjusting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-amber-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  if (!product) return null;

  return (
    <div>
      <Link
        to="/products"
        className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-amber-700 mb-6 transition-colors"
      >
        <ArrowLeft size={16} />
        Back to Products
      </Link>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Image */}
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm overflow-hidden">
          {product.image_url ? (
            <img
              src={product.image_url}
              alt={product.name}
              className="w-full h-80 object-cover"
            />
          ) : (
            <div className="w-full h-80 bg-amber-50 flex items-center justify-center">
              <Package size={64} className="text-amber-200" />
            </div>
          )}
        </div>

        {/* Details */}
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-6">
            <div className="flex items-start justify-between gap-4 mb-4">
              <div>
                <h1 className="text-2xl font-bold text-gray-800">{product.name}</h1>
                <p className="text-sm text-gray-400 mt-1">
                  {product.category_name || 'Uncategorized'}
                  {product.sku && <> &middot; SKU: {product.sku}</>}
                </p>
              </div>
              <span className={`text-sm px-3 py-1 rounded-full font-medium shrink-0 ${statusColors[product.status] || statusColors.available}`}>
                {statusLabels[product.status] || product.status}
              </span>
            </div>

            {product.description && (
              <p className="text-sm text-gray-600 mb-4 leading-relaxed">
                {product.description}
              </p>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-amber-50 rounded-lg">
                <p className="text-xs text-amber-600 mb-0.5">Price (INR)</p>
                <p className="text-lg font-bold text-amber-800">
                  {product.price_inr != null ? `₹${Number(product.price_inr).toLocaleString()}` : 'N/A'}
                </p>
              </div>
              <div className="p-3 bg-green-50 rounded-lg">
                <p className="text-xs text-green-600 mb-0.5">Price (USD)</p>
                <p className="text-lg font-bold text-green-800">
                  ${product.price_usd ? Number(product.price_usd).toFixed(2) : '0.00'}
                </p>
              </div>
            </div>

            <div className="flex gap-3 mt-5">
              <Link
                to={`/products/${id}/edit`}
                className="flex items-center gap-2 px-4 py-2 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors text-sm font-medium"
              >
                <Edit size={16} />
                Edit
              </Link>
              <button
                onClick={() => setDeleteModal(true)}
                className="flex items-center gap-2 px-4 py-2 border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors text-sm font-medium"
              >
                <Trash2 size={16} />
                Delete
              </button>
            </div>
          </div>

          {/* Artisan Info */}
          {(product.artisan_name || product.origin_state) && (
            <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-6">
              <h2 className="text-lg font-semibold text-gray-800 mb-3">Artisan Details</h2>
              {product.artisan_name && (
                <div className="flex items-center gap-2 mb-2">
                  <User size={16} className="text-amber-500" />
                  <span className="text-sm text-gray-700">{product.artisan_name}</span>
                </div>
              )}
              {product.origin_state && (
                <div className="flex items-center gap-2 mb-2">
                  <MapPin size={16} className="text-amber-500" />
                  <span className="text-sm text-gray-700">{product.origin_state}</span>
                </div>
              )}
              {product.artisan_story && (
                <p className="text-sm text-gray-500 mt-3 italic leading-relaxed border-l-2 border-amber-200 pl-3">
                  {product.artisan_story}
                </p>
              )}
            </div>
          )}

          {/* Inventory */}
          <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-6">
            <h2 className="text-lg font-semibold text-gray-800 mb-3">Inventory</h2>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">Current Stock</p>
                <p className="text-2xl font-bold text-gray-800">
                  {product.stock_quantity ?? 0}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleStockAdjust(-1)}
                  disabled={adjusting || (product.stock_quantity || 0) <= 0}
                  className="p-2 rounded-lg border border-gray-200 hover:bg-red-50 hover:border-red-200 text-gray-500 hover:text-red-600 transition-colors disabled:opacity-40"
                >
                  <Minus size={18} />
                </button>
                <span className="text-lg font-bold text-gray-800 w-12 text-center">
                  {product.stock_quantity ?? 0}
                </span>
                <button
                  onClick={() => handleStockAdjust(1)}
                  disabled={adjusting}
                  className="p-2 rounded-lg border border-gray-200 hover:bg-green-50 hover:border-green-200 text-gray-500 hover:text-green-600 transition-colors disabled:opacity-40"
                >
                  <Plus size={18} />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Delete Confirmation */}
      <Modal isOpen={deleteModal} onClose={() => setDeleteModal(false)} title="Delete Product">
        <p className="text-sm text-gray-600 mb-5">
          Are you sure you want to delete <span className="font-semibold">{product.name}</span>?
          This action cannot be undone.
        </p>
        <div className="flex justify-end gap-3">
          <button
            onClick={() => setDeleteModal(false)}
            className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleDelete}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm font-medium"
          >
            Delete
          </button>
        </div>
      </Modal>
    </div>
  );
}
