module LuxMPIExt

import Lux: MPIBackend, NCCLBackend, DistributedUtils, __is_extension_loaded, __set_device!,
            __unwrap_val
import LuxDeviceUtils: AbstractLuxDevice
import MPI

function DistributedUtils.__initialize(
        ::Val{:MPI}; cuda_devices=nothing, amdgpu_devices=nothing)
    !MPI.Initialized() && MPI.Init()
    DistributedUtils.MPI_Initialized[] = true

    local_rank = MPI.Comm_rank(MPI.COMM_WORLD)

    if cuda_devices !== missing && __unwrap_val(__is_extension_loaded(Val(:LuxCUDA)))
        if cuda_devices === nothing
            __set_device!(Val(:CUDA), nothing, local_rank)
        else
            __set_device!(Val(:CUDA), cuda_devices[local_rank])
        end
    end

    if amdgpu_devices !== missing && __unwrap_val(__is_extension_loaded(Val(:LuxAMDGPU)))
        if amdgpu_devices === nothing
            __set_device!(Val(:AMDGPU), nothing, local_rank)
        else
            __set_device!(Val(:AMDGPU), amdgpu_devices[local_rank])
        end
    end

    return
end

DistributedUtils.__get_distributed_backend(::Val{:MPI}) = MPIBackend(MPI.COMM_WORLD)

DistributedUtils.local_rank(backend::MPIBackend) = MPI.Comm_rank(backend.comm)

DistributedUtils.total_workers(backend::MPIBackend) = MPI.Comm_size(backend.comm)

# Broadcast

function DistributedUtils.__bcast!(
        backend::MPIBackend, sendrecvbuf, dev::AbstractLuxDevice; root=0)
    MPI.Bcast!(sendrecvbuf, backend.comm; root)
    return sendrecvbuf
end

function DistributedUtils.__bcast!(
        backend::MPIBackend, sendbuf, recvbuf, dev::AbstractLuxDevice; root=0)
    MPI.Bcast!(sendbuf, recvbuf, backend.comm; root)
    return recvbuf
end

# Allreduce

function DistributedUtils.__allreduce!(
        backend::MPIBackend, sendrecvbuf, op::F, dev::AbstractLuxDevice) where {F}
    MPI.Allreduce!(sendrecvbuf, op, backend.comm)
    if op === typeof(DistributedUtils.avg)
        sendrecvbuf ./= DistributedUtils.total_workers(backend)
    end
    return sendrecvbuf
end

function DistributedUtils.__allreduce!(
        backend::MPIBackend, sendbuf, recvbuf, op::F, dev::AbstractLuxDevice) where {F}
    MPI.Allreduce!(sendbuf, recvbuf, op, backend.comm)
    if op === typeof(DistributedUtils.avg)
        recvbuf ./= DistributedUtils.total_workers(backend)
    end
    return recvbuf
end

# Reduce

function DistributedUtils.__reduce!(backend::MPIBackend, sendrecvbuf, op::F,
        dev::AbstractLuxDevice; root::Int) where {F}
    MPI.Reduce!(sendrecvbuf, op, backend.comm; root)
    if op === typeof(DistributedUtils.avg)
        sendrecvbuf ./= DistributedUtils.total_workers(backend)
    end
    return sendrecvbuf
end

function DistributedUtils.__reduce!(backend::MPIBackend, sendbuf, recvbuf, op::F,
        dev::AbstractLuxDevice; root::Int) where {F}
    MPI.Reduce!(sendbuf, recvbuf, op, backend.comm; root)
    if op === typeof(DistributedUtils.avg)
        recvbuf ./= DistributedUtils.total_workers(backend)
    end
    return recvbuf
end

end
