<script lang="ts" setup>
import { registerPageTool } from '@opentiny/next-sdk'
import {
  Notify,
  Button as TinyButton,
  DialogBox as TinyDialogBox,
  Form as TinyForm,
  FormItem as TinyFormItem,
  Input as TinyInput,
  DatePicker as TinyDatePicker,
  Row as TinyRow,
  Col as TinyCol,
  Switch as TinySwitch,
  Modal as TinyModal,
} from '@opentiny/vue'
import { onMounted, onUnmounted, reactive, ref, nextTick } from 'vue'
import { useI18n } from 'vue-i18n'
import { {{table_name}} } from '@/store/models/{{db_name}}'
import { useAxiosRepo } from '@pinia-orm/axios'
import { useDisclosure } from '@/hooks/useDisclosure'
import { sleep, removeEmpty } from '@/utils/base-utils'

const emits = defineEmits<{
  {{camelTableName}}Change: []
  batchRemove: []
  export{{ClassName}}: []
  recycleBinChange: [boolean]
  batchRestore: []
  emptyRecycleBin: []
  batchPermanentDelete: []
}>()

const { open, onOpen, onClose } = useDisclosure()
const {{table_name}}Form = ref()
const i18n = useI18n()

const isRecycleBin = ref(false)

{{form_model}}

function onBatchRemove() {
  emits('batchRemove')
}

function onExport{{ClassName}}() {
  emits('export{{ClassName}}')
}

function onBatchRestore() {
  emits('batchRestore')
}

function onEmptyRecycleBin() {
  TinyModal.confirm({
    title: '清空回收站确认',
    message: '确定要清空回收站吗？此操作将彻底删除所有回收站中的数据，无法恢复！',
    onConfirm: () => {
      emits('emptyRecycleBin')
    },
  })
}

function onBatchPermanentDelete() {
  emits('batchPermanentDelete')
}

function handleRecycleBinChange(checked: boolean) {
  isRecycleBin.value = checked
  emits('recycleBinChange', checked)
}

{{validation_rules}}

function add{{ClassName}}() {
  {{table_name}}Form.value
    .validate()
    .then(() => {
      const submitData = { ...formModel }
      
{{number_conversion}}

      const cleanedData = removeEmpty(submitData)

      useAxiosRepo({{table_name}}).api().add{{ClassName}}(cleanedData)
        .then(() => {
          Object.keys(formModel).forEach((key) => {
            formModel[key] = ''
          })
{{reset_defaults}}
          emits('{{camelTableName}}Change')
        })
        .catch((reason) => {
          Notify({
            type: 'error',
            message: reason.response.data.message,
          })
        })
        .finally(() => {
          onClose()
        })
    })
}

let cleanupPageTool: () => void

onMounted(async () => {
  cleanupPageTool = registerPageTool({
    handlers: {
      'create-{{table_name}}': async ({{handler_param}}: any) => {
        {{create_handler_params}}
        
        onOpen()
        await sleep(500)
        
{{set_form_values}}
        
        await nextTick()
        await sleep(500)
        
        try {
          await add{{ClassName}}()
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
              text: `创建{{table_name}}失败: ${error.response?.data?.message || '未知错误'}`
            }]
          }
        }
      },
    },
  })
})

onUnmounted(() => cleanupPageTool?.())
</script>

<template>
  <div class="{{kebabTableName}}-add-container">
    <div class="{{kebabTableName}}-add-btn">
      <template v-if="!isRecycleBin">
        <TinyButton v-permission="'{{db_name}}:{{table_name}}:add'" show-footer type="primary" round @click="onOpen">
          {{ $t('page.Add') }}
        </TinyButton>
        <TinyButton v-permission="'{{db_name}}:{{table_name}}:batch-del'" round @click="onBatchRemove">
          {{ $t('page.BatchDelete') }}
        </TinyButton>
        <TinyButton v-permission="'{{db_name}}:{{table_name}}:all'" round @click="onExport{{ClassName}}">
          {{ $t('page.Export') }}
        </TinyButton>
      </template>
      
      <template v-else>
        <TinyButton v-permission="'{{db_name}}:{{table_name}}:batch-del'" type="danger" round @click="onEmptyRecycleBin">
          清空
        </TinyButton>
        <TinyButton v-permission="'{{db_name}}:{{table_name}}:batch-del'" round @click="onBatchRestore">
          批量恢复
        </TinyButton>
        <TinyButton v-permission="'{{db_name}}:{{table_name}}:batch-del'" type="danger" round @click="onBatchPermanentDelete">
          批量彻底删除
        </TinyButton>
      </template>
    </div>
    <div class="recycle-bin-switch">
      <TinySwitch
        v-model="isRecycleBin"
        :show-text="true"
        :checked-text="'回收站'"
        :unchecked-text="'回收站'"
        @change="handleRecycleBinChange"
      />
    </div>
    <TinyDialogBox
      v-model:visible="open"
      :title="$t('page.Add')"
      width="800px"
      :close-on-click-modal="false"
      dialog-class="{{kebabTableName}}-dialog-box"
    >
      <TinyForm
        ref="{{table_name}}Form"
        :model="formModel"
        :rules="rules"
        label-position="left"
        label-width="120px"
      >
{{form_rows}}
      </TinyForm>
      <template #footer>
        <TinyButton size="small" @click="onClose">
          {{ $t('menu.btn.cancel') }}
        </TinyButton>
        <TinyButton
          size="small"
          :text="$t('page.Add')"
          type="primary"
          round
          @click="add{{ClassName}}"
        />
      </template>
    </TinyDialogBox>
  </div>
</template>

<style scoped lang="less">
.{{kebabTableName}}-dialog-box :deep(.tiny-dialog-box .tiny-dialog-box__body) {
  padding-top: 0px;
  padding-bottom: 0px;
}
.tiny-button {
  width: 96px;
  margin-right: 12px;
}
.{{kebabTableName}}-add-container {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 0 24px 10px;
}
.{{kebabTableName}}-add-btn {
  display: flex;
  align-items: center;
}
.recycle-bin-switch {
  margin-right: 10px;
}
</style>