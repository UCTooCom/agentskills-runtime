<script lang="ts" setup>
import { ref } from 'vue'
import GeneralLayout from '@/layout/general-layout.vue'
import add{{ClassName}} from './components/add-{{kebabTableName}}.vue'
import {{camelTableName}}Table from './components/{{kebabTableName}}-table.vue'

const {{camelTableName}}TableRef = ref()
const isRecycleBin = ref(false)

function onChange() {
  {{camelTableName}}TableRef.value.reload()
}

function onRemove() {
  {{camelTableName}}TableRef.value.batchRemove{{ClassName}}()
}

function onExport() {
  {{camelTableName}}TableRef.value.export{{ClassName}}()
}

function onRecycleBinChange(status: boolean) {
  isRecycleBin.value = status
}

function onBatchRestore() {
  {{camelTableName}}TableRef.value.batchRestore{{ClassName}}()
}

function onEmptyRecycleBin() {
  if ({{camelTableName}}TableRef.value && {{camelTableName}}TableRef.value.emptyRecycleBin) {
    {{camelTableName}}TableRef.value.emptyRecycleBin()
  }
}

function onBatchPermanentDelete() {
  {{camelTableName}}TableRef.value.batchRemove{{ClassName}}()
}
</script>

<template>
  <GeneralLayout :breadcrumb="['menu.database', '{{db_name}}.{{table_name}}']">
    <add-{{kebabTableName}}
      class="{{kebabTableName}}-add-btn"
      @{{kebabTableName}}-change="onChange"
      @batch-remove="onRemove"
      @export-{{kebabTableName}}="onExport"
      @recycle-bin-change="onRecycleBinChange"
      @batch-restore="onBatchRestore"
      @empty-recycle-bin="onEmptyRecycleBin"
      @batch-permanent-delete="onBatchPermanentDelete"
    />
    <{{kebabTableName}}-table 
      ref="{{camelTableName}}TableRef" 
      :recycle-bin-status="isRecycleBin" 
    />
  </GeneralLayout>
</template>

<style scoped lang="less">
.{{kebabTableName}}-add-btn {
  padding: 10px 0 24px 10px;
}
</style>
