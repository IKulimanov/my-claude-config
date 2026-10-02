# Vue Testing Reference: Vitest + Vue Test Utils

## Component Testing

```typescript
import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createTestingPinia } from '@pinia/testing'
import OrderList from '@/components/OrderList.vue'

describe('OrderList', () => {
  it('should render orders from store', () => {
    const wrapper = mount(OrderList, {
      global: {
        plugins: [createTestingPinia({
          initialState: {
            order: { orders: [{ id: '1', name: 'Test Order', status: 'pending' }] },
          },
        })],
      },
    })

    expect(wrapper.text()).toContain('Test Order')
  })

  it('should emit select when order clicked', async () => {
    const wrapper = mount(OrderList, {
      global: {
        plugins: [createTestingPinia({
          initialState: {
            order: { orders: [{ id: '1', name: 'Test', status: 'pending' }] },
          },
        })],
      },
    })

    await wrapper.find('[data-testid="order-item"]').trigger('click')
    expect(wrapper.emitted('select')).toHaveLength(1)
    expect(wrapper.emitted('select')![0]).toEqual([{ id: '1' }])
  })

  it('should show loading state', () => {
    const wrapper = mount(OrderList, {
      global: {
        plugins: [createTestingPinia({
          initialState: { order: { loading: true } },
        })],
      },
    })

    expect(wrapper.find('[data-testid="loading"]').exists()).toBe(true)
  })
})
```

## Composable Testing

```typescript
import { describe, it, expect } from 'vitest'
import { useAsync } from '@/composables/useAsync'
import { flushPromises } from '@vue/test-utils'

describe('useAsync', () => {
  it('should handle successful async operation', async () => {
    const { data, loading, error, execute } = useAsync(
      () => Promise.resolve('result')
    )

    expect(loading.value).toBe(false)

    execute()
    expect(loading.value).toBe(true)

    await flushPromises()
    expect(data.value).toBe('result')
    expect(loading.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('should handle error', async () => {
    const { error, execute } = useAsync(
      () => Promise.reject(new Error('fail'))
    )

    await execute()
    await flushPromises()
    expect(error.value).toBe('fail')
  })
})
```

## Store Testing

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useOrderStore } from '@/stores/order'
import { orderApi } from '@/api/order'

vi.mock('@/api/order')

describe('useOrderStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('fetchOrders_shouldPopulateOrders', async () => {
    const mockOrders = [{ id: '1', name: 'Test' }]
    vi.mocked(orderApi.getAll).mockResolvedValue(mockOrders)

    const store = useOrderStore()
    await store.fetchOrders()

    expect(store.orders).toEqual(mockOrders)
    expect(store.loading).toBe(false)
  })

  it('fetchOrders_shouldSetError_whenApiFails', async () => {
    vi.mocked(orderApi.getAll).mockRejectedValue(new Error('Network'))

    const store = useOrderStore()
    await store.fetchOrders()

    expect(store.error).toBe('Network')
    expect(store.orders).toEqual([])
  })
})
```

## Testing Rules

- Use `data-testid` attributes for test selectors, not CSS classes or tag names.
- Test behavior, not implementation: check what user sees, not internal state.
- Use `@pinia/testing` with `createTestingPinia` for store mocking in component tests.
- Use `flushPromises()` after async operations.
- Mount with `mount()` for integration, `shallowMount()` for isolation.
- Always test: rendering, user interactions, emitted events, error states.
- Don't test Vue internals (reactivity system, lifecycle hooks directly).
- Keep test files next to source: `OrderList.vue` -> `OrderList.spec.ts` or `__tests__/` directory.
- Mock API calls with `vi.mock()`, never make real HTTP requests in unit tests.
- One test = one user-facing behavior.

## Naming Convention

Same approach as Java convention adapted for JS:
- `componentName_shouldBehavior_whenCondition`
- Or describe/it block structure with clear descriptions.
