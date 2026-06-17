<script lang="ts" setup>
import type { FilterType, InputFilterValue } from '@/types/global'
import {
  Button as TinyButton,
  Grid as TinyGrid,
  GridColumn as TinyGridColumn,
  TinyModal,
  Popconfirm as TinyPopconfirm,
  Modal as TinyModalComponent,
  Checkbox as TinyCheckbox,
  Select as TinySelect,
  Option as TinyOption,
  Input as TinyInput,
} from '@opentiny/vue'
import { iconDel, iconRefresh, iconPlus, iconMinus } from '@opentiny/vue-icon'
import { computed, ref, watch, reactive, onMounted, onUnmounted, nextTick } from 'vue'
import { {{table_name}} } from '@/store/models/{{db_name}}'
import { useAxiosRepo } from '@pinia-orm/axios'
import useLoading from '@/hooks/loading'
import { useResponsive, useResponsiveSize } from '@/hooks/responsive'
import { useUserStore } from '@/store'
import { registerPageTool } from '@opentiny/next-sdk'
import { sleep } from '@/utils/base-utils'
import EditForm from './edit-form.vue'

const { gridSize } = useResponsiveSize()
const { sm } = useResponsive()

const IconDel = iconDel()
const IconRestore = iconRefresh()
const IconPlus = iconPlus()
const IconMinus = iconMinus()
const grid = ref()

const userStore = useUserStore()
const rolePermission = computed(() => userStore.rolePermission)

const editModal = ref(false)
const editFormRef = ref()
const current{{ClassName}} = ref<Partial<{{table_name}}>>({})
const readonly = ref(false)

const isRecycleBin = ref(false)
const checkedHardDelete = ref(false)

const props = defineProps<{
  recycleBinStatus: boolean
}>()

watch(() => props.recycleBinStatus, (newStatus) => {
  isRecycleBin.value = newStatus
  grid.value?.handleFetch()
}, { immediate: true })

const pagerConfigSm = ref({
  attrs: {
    currentPage: 1,
    pageSize: 10,
    pageSizes: [10, 20, 50, 100],
    total: 0,
    align: 'right',
    layout: 'total, prev, pager, next',
  },
})

const pagerConfigLg = ref({
  attrs: {
    currentPage: 1,
    pageSize: 10,
    pageSizes: [10, 20, 50, 100],
    total: 0,
    align: 'right',
    layout: 'sizes, total, prev, pager, next, jumper',
  },
})

const { loading, setLoading } = useLoading()

interface FilterCondition {
  id: string
  field: string
  operator: string
  value: string
}

const filterConditions = ref<FilterCondition[]>([
  {
    id: '1',
    field: '{{first_field}}',
    operator: 'contains',
    value: ''
  }
])

const availableFields = [
{{available_fields}}
]

const operators = [
  { label: '等于', value: 'equals' },
  { label: '不等于', value: 'not' },
  { label: '小于', value: 'lt' },
  { label: '小于等于', value: 'lte' },
  { label: '大于', value: 'gt' },
  { label: '大于等于', value: 'gte' },
  { label: '包含', value: 'contains' },
  { label: '开头是', value: 'startsWith' },
  { label: '结尾是', value: 'endsWith' },
  { label: '在列表中', value: 'in' },
  { label: '不在列表中', value: 'notIn' },
  { label: '已设置', value: 'isSet' },
  { label: '在区间内', value: 'between' },
  { label: '不在区间内', value: 'notBetween' }
]

function addFilterCondition() {
  const newId = (filterConditions.value.length + 1).toString()
  filterConditions.value.push({
    id: newId,
    field: '{{first_field}}',
    operator: 'contains',
    value: ''
  })
}

function removeFilterCondition(id: string) {
  const index = filterConditions.value.findIndex(condition => condition.id === id)
  if (index > -1) {
    filterConditions.value.splice(index, 1)
  }
}

function applyFilters() {
  grid.value?.handleFetch()
}

function resetFilters() {
  filterConditions.value = [
    {
      id: '1',
      field: '{{first_field}}',
      operator: 'contains',
      value: ''
    }
  ]
  grid.value?.handleFetch()
}

function filterInputValue2String(value: InputFilterValue) {
  let str = ''
  if (value.relation === 'contains') {
    str += '%'
  }
  str += value.text
  if (value.relation === 'startwith' || value.relation === 'contains') {
    str += '%'
  }
  return str
}

function buildFilterQuery() {
  const filters: any = {}
  
  filterConditions.value.forEach(condition => {
    if (condition.value || condition.operator === 'is_null' || condition.operator === 'not_null') {
      filters[condition.field] = { [condition.operator]: condition.value }
    }
  })
  
  return filters
}

function getData({
  page,
  filters,
}: {
  page: { pageSize: number, currentPage: number }
  filters: FilterType
}) {
{{filter_variables}}
  const { pageSize, currentPage } = page
  setLoading(true)
  
  const searchParams: any = { {{filter_params}} }

  const advancedFilters = buildFilterQuery()
  if (Object.keys(advancedFilters).length > 0) {
    searchParams.filter = JSON.stringify(advancedFilters)
  }
  
  if (isRecycleBin.value) {
    if (searchParams.filter) {
      const existingFilter = JSON.parse(searchParams.filter)
      existingFilter.deleted_at = { not: null }
      searchParams.filter = JSON.stringify(existingFilter)
    } else {
      searchParams.filter = JSON.stringify({ deleted_at: { not: null } })
    }
  } else {
    if (searchParams.filter) {
      const existingFilter = JSON.parse(searchParams.filter)
      existingFilter.deleted_at = null
      searchParams.filter = JSON.stringify(existingFilter)
    } else {
      searchParams.filter = JSON.stringify({ deleted_at: null })
    }
  }
  
  return new Promise((resolve) => {
    useAxiosRepo({{table_name}}).api().get{{ClassName}}List(currentPage, pageSize, searchParams)
      .then((result) => {
        const res = result.response.data as any
        let items: any[] = []
        let total = 0
        
        if (Array.isArray(res)) {
          items = res
          total = res.length
        } else if (typeof res === 'object' && res !== null) {
          items = res.{{table_name}}s || res.items || []
          total = res.totalCount || res.meta?.totalItems || 0
        }

        resolve({
          result: items.map((item: any) => {
            return {
{{return_fields}}
            }
          }),
          page: {
            total: total,
          },
        })
      })
      .finally(() => {
        setLoading(false)
      })
  })
}

function onEditClosed({ row }: { row: Record<string, any> }) {
  if (grid.value.hasRowChange(row)) {
    useAxiosRepo({{table_name}}).api().edit{{ClassName}}({
{{edit_fields}}
    })
      .then(() => {
        TinyModal.message({
          message: '更新成功',
          status: 'success',
        })
      })
      .catch((error) => {
        grid.value.revertData(row)
        if (error.response && error.response.data) {
          const errorMessage = error.response.data.message || '未知错误'
          TinyModal.message({
            message: errorMessage,
            status: 'error',
          })
        }
      })
      .finally(() => {
        setLoading(false)
      })
  }
}

function batchRemove{{ClassName}}() {
  const rowIds = grid.value.getAllSelection().flatMap(row => row.id)
  if (rowIds.length === 0) {
    TinyModal.message({
      message: '请选择要删除的{{table_name}}',
      status: 'error',
    })
    return
  }
  
  const isHardDelete = isRecycleBin.value
  
  TinyModal.confirm({
    title: isHardDelete ? '彻底删除确认' : '删除确认',
    message: isHardDelete ? '确定要彻底删除选中的{{table_name}}吗？删除后无法恢复！' : '确定要批量删除选中的{{table_name}}吗？',
    onConfirm: () => {
      setLoading(true)
      
      const deleteParams: any = { ids: JSON.stringify(rowIds) }
      if (isHardDelete) {
        deleteParams.force = 1
      }
      
      useAxiosRepo({{table_name}}).api().batchDelete{{ClassName}}(deleteParams)
        .then(() => {
          TinyModal.message({
            message: isHardDelete ? '批量彻底删除成功' : '批量删除成功',
            status: 'success',
          })
          grid.value.handleFetch()
        })
        .catch((error) => {
          if (error.response && error.response.data) {
            const errorMessage = error.response.data.errmsg || error.response.data.message || '未知错误'
            TinyModal.message({
              message: errorMessage,
              status: 'error',
            })
          }
        })
        .finally(() => {
          setLoading(false)
        })
    },
  })
}

function remove{{ClassName}}(row: any) {
  setLoading(true)
  
  const deleteParams: any = { id: row.id }
  
  if (isRecycleBin.value || checkedHardDelete.value) {
    deleteParams.force = 1
  }
  
  useAxiosRepo({{table_name}}).api().delete{{ClassName}}(deleteParams)
    .then(() => {
      TinyModal.message({
        message: (isRecycleBin.value || checkedHardDelete.value) ? '彻底删除成功' : '删除成功',
        status: 'success',
      })
      grid.value.handleFetch()
      checkedHardDelete.value = false
    })
    .catch((error) => {
      if (error.response && error.response.data) {
        const errorMessage = error.response.data.errmsg || error.response.data.message || '未知错误'
        TinyModal.message({
          message: errorMessage,
          status: 'error',
        })
      }
    })
    .finally(() => {
      setLoading(false)
    })
}

function restore{{ClassName}}(row: any) {
  setLoading(true)
  useAxiosRepo({{table_name}}).api().edit{{ClassName}}({ id: row.id, deleted_at: '0' })
    .then(() => {
      TinyModal.message({
        message: '恢复成功',
        status: 'success',
      })
      grid.value.handleFetch()
    })
    .catch((error) => {
      if (error.response && error.response.data) {
        const errorMessage = error.response.data.errmsg || error.response.data.message || '未知错误'
        TinyModal.message({
          message: errorMessage,
          status: 'error',
        })
      }
    })
    .finally(() => {
      setLoading(false)
    })
}

function batchRestore{{ClassName}}() {
  const rowIds = grid.value.getAllSelection().flatMap(row => row.id)
  if (rowIds.length === 0) {
    TinyModal.message({
      message: '请选择要恢复的{{table_name}}',
      status: 'error',
    })
    return
  }
  TinyModal.confirm({
    title: '恢复确认',
    message: '确定要恢复选中的{{table_name}}吗？',
    onConfirm: () => {
      setLoading(true)
      useAxiosRepo({{table_name}}).api().batchRestore{{ClassName}}(rowIds)
        .then(() => {
          TinyModal.message({
            message: '批量恢复成功',
            status: 'success',
          })
          grid.value.handleFetch()
        })
        .catch((error) => {
          if (error.response && error.response.data) {
            const errorMessage = error.response.data.errmsg || error.response.data.message || '未知错误'
            TinyModal.message({
              message: errorMessage,
              status: 'error',
            })
          }
        })
        .finally(() => {
          setLoading(false)
        })
    },
  })
}

function emptyRecycleBin() {
  TinyModal.confirm({
    title: '清空回收站确认',
    message: '确定要清空回收站吗？此操作将彻底删除所有回收站中的数据，无法恢复！',
    onConfirm: () => {
      setLoading(true)
      useAxiosRepo({{table_name}}).api().emptyRecycleBin()
        .then(() => {
          TinyModal.message({
            message: '清空回收站成功',
            status: 'success',
          })
          grid.value.handleFetch()
        })
        .catch((error) => {
          if (error.response && error.response.data) {
            const errorMessage = error.response.data.errmsg || error.response.data.message || '未知错误'
            TinyModal.message({
              message: errorMessage,
              status: 'error',
            })
          }
        })
        .finally(() => {
          setLoading(false)
        })
    },
  })
}

function onEdit(row: any) {
  current{{ClassName}}.value = { ...row }
  readonly.value = false
  editModal.value = true
}

function onView(row: any) {
  current{{ClassName}}.value = { ...row }
  readonly.value = true
  editModal.value = true
}

function onEditCancel() {
  editModal.value = false
  current{{ClassName}}.value = {}
}

function onEditConfirm() {
  setLoading(true)
  editFormRef.value
    .valid()
    .then(() => {
      const formData = editFormRef.value.getFormData()
      
      if (!formData) {
        TinyModal.message({
          message: '没有修改任何字段',
          status: 'info',
        })
        editModal.value = false
        setLoading(false)
        return
      }
      
      useAxiosRepo({{table_name}}).api().edit{{ClassName}}(formData)
        .then(() => {
          TinyModal.message({
            message: '更新成功',
            status: 'success',
          })
          editModal.value = false
          grid.value.handleFetch()
        })
        .catch((error) => {
          if (error.response && error.response.data) {
            const errorMessage = error.response.data.errmsg || error.response.data.message || '未知错误'
            TinyModal.message({
              message: errorMessage,
              status: 'error',
            })
          }
        })
        .finally(() => {
          setLoading(false)
        })
    })
    .catch(() => {
      setLoading(false)
    })
}

const fetchData = ref({
  api: getData,
  filter: true,
})

function export{{ClassName}}() {
  const selectedRows = grid.value.getAllSelection()
  if (selectedRows.length === 0) {
    TinyModal.message({
      message: '请选择要导出的{{table_name}}',
      status: 'error',
    })
    return
  }
  grid.value.exportCsv({
    filename: '{{table_name}}_export',
    original: true,
    isHeader: false,
    useTabs: false,
    data: selectedRows,
  })
}

let cleanupPageTool: () => void

onMounted(async () => {
  cleanupPageTool = registerPageTool({
    route: '/{{db_name}}/{{table_name}}',
    handlers: {
      'query-{{table_name}}-list': async ({{handler_param}}: any) => {
        const { page = 1, pageSize = 10, {{query_params}} } = {{handler_param}}
        
        if (sm.value) {
          pagerConfigSm.value.attrs.currentPage = page
          pagerConfigSm.value.attrs.pageSize = pageSize
        } else {
          pagerConfigLg.value.attrs.currentPage = page
          pagerConfigLg.value.attrs.pageSize = pageSize
        }
        
{{set_filter_conditions}}
        
        await nextTick()
        grid.value?.handleFetch()
        
        return {
          content: [{
            type: 'text' as const,
            text: `查询{{table_name}}列表成功，页码: ${page}，每页数量: ${pageSize}`
          }]
        }
      },
      
      'create-{{table_name}}': async ({{handler_param}}: any) => {
        const { {{create_params}} } = {{handler_param}}
        
        if (!{{handler_param}}.{{first_field}}) {
          return {
            content: [{
              type: 'text' as const,
              text: '创建失败：{{first_field}}字段不能为空'
            }]
          }
        }
        
        setLoading(true)
        try {
          await useAxiosRepo({{table_name}}).api().add{{ClassName}}({
{{create_data}}
          })
          grid.value.handleFetch()
          
          return {
            content: [{
              type: 'text' as const,
              text: `创建{{table_name}}成功，{{first_field}}: ${{{handler_param}}.{{first_field}}}`
            }]
          }
        } catch (error: any) {
          return {
            content: [{
              type: 'text' as const,
              text: `创建失败: ${error.response?.data?.message || '未知错误'}`
            }]
          }
        } finally {
          setLoading(false)
        }
      },
      
      'edit-{{table_name}}': async ({{handler_param}}: any) => {
        const { id, ...updateFields } = {{handler_param}}
        
        if (!id) {
          return {
            content: [{
              type: 'text' as const,
              text: '编辑失败：ID不能为空'
            }]
          }
        }
        
        const tableData = grid.value.getTableData().fullData
        const targetRow = tableData.find((row: any) => row.id === id)
        
        if (!targetRow) {
          return {
            content: [{
              type: 'text' as const,
              text: `未找到ID为 ${id} 的{{table_name}}`
            }]
          }
        }
        
        current{{ClassName}}.value = { ...targetRow, ...updateFields }
        readonly.value = false
        editModal.value = true
        
        await nextTick()
        await sleep(500)
        
        onEditConfirm()
        
        return {
          content: [{
            type: 'text' as const,
            text: `编辑{{table_name}}成功，ID: ${id}`
          }]
        }
      },
      
      'delete-{{table_name}}': async ({{handler_param}}: any) => {
        const { id, ids, force = false } = {{handler_param}}
        
        if (ids && Array.isArray(ids)) {
          const deleteParams: any = { ids: JSON.stringify(ids) }
          if (force) {
            deleteParams.force = 1
          }
          
          setLoading(true)
          try {
            await useAxiosRepo({{table_name}}).api().batchDelete{{ClassName}}(deleteParams)
            grid.value.handleFetch()
            return {
              content: [{
                type: 'text' as const,
                text: `批量删除{{table_name}}成功，共删除 ${ids.length} 条记录`
              }]
            }
          } catch (error: any) {
            return {
              content: [{
                type: 'text' as const,
                text: `批量删除失败: ${error.response?.data?.message || '未知错误'}`
              }]
            }
          } finally {
            setLoading(false)
          }
        } else if (id) {
          const deleteParams: any = { id }
          if (force) {
            deleteParams.force = 1
          }
          
          setLoading(true)
          try {
            await useAxiosRepo({{table_name}}).api().delete{{ClassName}}(deleteParams)
            grid.value.handleFetch()
            return {
              content: [{
                type: 'text' as const,
                text: `删除{{table_name}}成功，ID: ${id}`
              }]
            }
          } catch (error: any) {
            return {
              content: [{
                type: 'text' as const,
                text: `删除失败: ${error.response?.data?.message || '未知错误'}`
              }]
            }
          } finally {
            setLoading(false)
          }
        }
        
        return {
          content: [{
            type: 'text' as const,
            text: '未提供有效的删除参数'
          }]
        }
      },
      
      'restore-{{table_name}}': async ({{handler_param}}: any) => {
        const { id } = {{handler_param}}
        
        if (!id) {
          return {
            content: [{
              type: 'text' as const,
              text: '恢复失败：ID不能为空'
            }]
          }
        }
        
        isRecycleBin.value = true
        await nextTick()
        await sleep(500)
        
        grid.value?.handleFetch()
        await sleep(500)
        
        setLoading(true)
        try {
          await useAxiosRepo({{table_name}}).api().edit{{ClassName}}({ id, deleted_at: '0' })
          grid.value.handleFetch()
          
          return {
            content: [{
              type: 'text' as const,
              text: `恢复{{table_name}}成功，ID: ${id}`
            }]
          }
        } catch (error: any) {
          return {
            content: [{
              type: 'text' as const,
              text: `恢复失败: ${error.response?.data?.message || '未知错误'}`
            }]
          }
        } finally {
          setLoading(false)
        }
      },
    },
  })
})

onUnmounted(() => cleanupPageTool?.())

defineExpose({
  reload: () => {
    grid.value.handleFetch()
  },
  batchRemove{{ClassName}},
  export{{ClassName}},
  batchRestore{{ClassName}},
  emptyRecycleBin,
})
</script>

<template>
  <div class="search-filter-container">
      <div class="filter-header">
        <TinyButton type="text" :icon="IconPlus" @click="addFilterCondition">
          添加筛选条件
        </TinyButton>
        <div style="display: flex; gap: 12px;">
          <TinyButton type="default" @click="resetFilters">重置</TinyButton>
          <TinyButton type="primary" @click="applyFilters">搜索</TinyButton>
        </div>
      </div>
      <div class="filter-conditions">
        <div class="filter-row" v-for="condition in filterConditions" :key="condition.id">
          <TinySelect
            v-model="condition.field"
            style="width: 120px; margin-right: 10px"
          >
            <TinyOption
              v-for="field in availableFields"
              :key="field.value"
              :value="field.value"
            >
              {{ field.label }}
            </TinyOption>
          </TinySelect>
          
          <TinySelect
            v-model="condition.operator"
            style="width: 120px; margin-right: 10px"
          >
            <TinyOption
              v-for="op in operators"
              :key="op.value"
              :value="op.value"
            >
              {{ op.label }}
            </TinyOption>
          </TinySelect>
          
          <TinyInput 
            v-model="condition.value"
            style="width: 150px; margin-right: 10px"
            :disabled="condition.operator === 'is_null' || condition.operator === 'not_null'"
          />
          
          <TinyButton 
            type="text" 
            :icon="IconMinus" 
            @click="removeFilterCondition(condition.id)"
            v-if="filterConditions.length > 1"
          />
        </div>
      </div>
    </div>

  <TinyGrid
    :key="sm ? 'sm' : 'lg'"
    ref="grid"
    :pager="sm ? pagerConfigSm : pagerConfigLg"
    :fetch-data="fetchData"
    :edit-config="
      rolePermission.includes('{{db_name}}:{{table_name}}:edit') && !isRecycleBin
        ? { trigger: 'click', mode: 'cell', showStatus: true }
        : undefined
    "
    :loading="loading"
    :auto-resize="true"
    remote-filter
    refresh
    :size="gridSize"
    align="center"
    @edit-closed="onEditClosed"
  >
    <TinyGridColumn type="selection" width="30px" />
{{grid_columns}}
    <TinyGridColumn :title="$t('searchTable.columns.operations')" width="14%" fixed="right">
      <template #default="data">
        <template v-if="isRecycleBin">
          <TinyButton
            v-permission="'{{db_name}}:{{table_name}}:edit'"
            type="text"
            @click="restore{{ClassName}}(data.row)"
          >
            <IconRestore class="operation-icon" />
            恢复
          </TinyButton>
          <TinyPopconfirm
            title="确定要彻底删除此{{table_name}}吗？删除后无法恢复！"
            type="info"
            trigger="click"
            @confirm="remove{{ClassName}}(data.row)"
          >
            <template #reference>
              <TinyButton
                v-permission="'{{db_name}}:{{table_name}}:del'"
                type="text"
              >
                <IconDel class="operation-icon" />
                彻底删除
              </TinyButton>
            </template>
          </TinyPopconfirm>
        </template>
        <template v-else>
          <TinyButton
            v-permission="'{{db_name}}:{{table_name}}:edit'"
            type="text"
            @click="onEdit(data.row)"
          >
            编辑
          </TinyButton>
          <TinyButton
            v-permission="'{{db_name}}:{{table_name}}:all'"
            type="text"
            @click="onView(data.row)"
          >
            查看
          </TinyButton>
          <TinyPopconfirm
            title="确定要删除此{{table_name}}吗？"
            type="info"
            trigger="click"
            @confirm="remove{{ClassName}}(data.row)"
          >
            <template #reference>
              <TinyButton
                v-permission="'{{db_name}}:{{table_name}}:del'"
                type="text"
              >
                <IconDel class="operation-icon" />
                {{ $t('page.Delete') }}
              </TinyButton>
            </template>
          </TinyPopconfirm>
        </template>
      </template>
    </TinyGridColumn>
  </TinyGrid>

  <TinyModalComponent
    v-model="editModal"
    show-footer
    :mask-closable="true"
    width="800px"
    height="auto"
    resize
    :title="readonly ? '查看{{table_name}}' : '编辑{{table_name}}'"
    @close="onEditCancel"
  >
    <EditForm
      v-if="editModal"
      ref="editFormRef"
      :{{kebabTableName}}-data="current{{ClassName}}"
      :readonly="readonly"
    />
    <template #footer>
      <TinyButton
        v-if="!readonly"
        type="primary"
        :loading="loading"
        @click="onEditConfirm"
      >
        确认
      </TinyButton>
      <TinyButton @click="onEditCancel">
        取消
      </TinyButton>
    </template>
  </TinyModalComponent>
</template>

<style scoped lang="less">
.operation-icon {
  margin-right: 3px;
  fill: currentColor;
}

.search-filter-container {
  margin-bottom: 20px;
  padding: 15px;
  background-color: #f5f7fa;
  border-radius: 4px;
}

.filter-conditions {
  border-top: 1px solid #e4e7ed;
  padding-top: 15px;
}

.filter-row {
  display: flex;
  align-items: center;
  margin-bottom: 10px;
}

.filter-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 15px;
}
</style>